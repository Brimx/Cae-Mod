#include "gpu.hpp"

#include "../Config/config.hpp"
#include "../Config/serviceconfig.hpp"
#include "sensorslib.hpp"

#include <qdir.h>
#include <qdiriterator.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qhash.h>
#include <qpair.h>
#include <qregularexpression.h>
#include <qset.h>

namespace caelestia::services {

namespace {

QStringList gpuBusyFiles() {
    static const QRegularExpression cardRe(QStringLiteral("^card\\d+$"));

    QStringList files;
    QDirIterator it(QStringLiteral("/sys/class/drm"), QDir::Dirs | QDir::NoDotAndDotDot);
    while (it.hasNext()) {
        const QString path = it.next();
        if (!cardRe.match(it.fileName()).hasMatch()) {
            continue;
        }
        const QString busy = path + QStringLiteral("/device/gpu_busy_percent");
        if (QFile::exists(busy)) {
            files << busy;
        }
    }
    return files;
}

QString cleanName(QString s) {
    static const QRegularExpression noise(
        QStringLiteral("\\(R\\)|\\(TM\\)|Graphics"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression spaces(QStringLiteral("\\s+"));
    s.replace(noise, QString());
    s.replace(spaces, QStringLiteral(" "));
    return s.trimmed();
}

QString parseNvidiaName(const QByteArray& out) {
    const QString first = QString::fromUtf8(out).split('\n').value(0).trimmed();
    return first.isEmpty() ? QString() : cleanName(first);
}

QString parseGlxinfoName(const QByteArray& out) {
    const QStringList lines = QString::fromUtf8(out).split('\n');
    for (const QString& line : lines) {
        const qsizetype idx = line.indexOf(QStringLiteral("Device:"));
        if (idx < 0) {
            continue;
        }

        QString rest = line.mid(idx + 7);
        const qsizetype paren = rest.indexOf('(');
        if (paren >= 0) {
            rest = rest.left(paren);
        }

        const QString cleaned = cleanName(rest);
        if (!cleaned.isEmpty()) {
            return cleaned;
        }
    }

    return QString();
}

QString parseLspciName(const QByteArray& out) {
    static const QRegularExpression lineRe(
        QStringLiteral("vga|3d controller|display"), QRegularExpression::CaseInsensitiveOption);

    const QStringList lines = QString::fromUtf8(out).split('\n');
    QString match;
    for (const QString& line : lines) {
        if (lineRe.match(line).hasMatch()) {
            match = line;
            break;
        }
    }

    if (match.isEmpty()) {
        return QString();
    }

    static const QRegularExpression bracketRe(QStringLiteral("\\[([^\\]]+)\\][^\\[]*$"));
    const auto bracket = bracketRe.match(match);
    if (bracket.hasMatch()) {
        return cleanName(bracket.captured(1));
    }

    // Split on a colon followed by whitespace so the PCI slot ("00:02.0") is not
    // mistaken for the class/name separator ("controller: Device").
    static const QRegularExpression colonRe(QStringLiteral(":\\s+(.+)"));
    const auto colon = colonRe.match(match);
    if (colon.hasMatch()) {
        return cleanName(colon.captured(1));
    }

    return QString();
}

struct NameSource {
    QString program;
    QStringList args;
    QString (*parse)(const QByteArray&);
};

// Name probes in priority order; the first non-empty result wins. The NVIDIA
// probe is first and doubles as the type probe (see finishNameSource).
const std::array<NameSource, 3>& nameSources() {
    static const std::array<NameSource, 3> sources = { {
        { QStringLiteral("nvidia-smi"), { QStringLiteral("--query-gpu=name"), QStringLiteral("--format=csv,noheader") },
            &parseNvidiaName },
        { QStringLiteral("glxinfo"), { QStringLiteral("-B") }, &parseGlxinfoName },
        { QStringLiteral("lspci"), {}, &parseLspciName },
    } };
    return sources;
}

// Index of the NVIDIA source within nameSources(); its result also drives type.
constexpr int kNvidiaSource = 0;

} // namespace

Gpu::Gpu(QObject* parent)
    : TickingService(parent) {
    m_busyFiles = gpuBusyFiles();

    auto* svc = caelestia::config::GlobalConfig::instance()->services();
    m_userType = parseType(svc->gpuType());
    QObject::connect(svc, &caelestia::config::ServiceConfig::gpuTypeChanged, this, [this, svc] {
        setUserType(parseType(svc->gpuType()));
    });

    detectGpu();
}

Gpu::Type Gpu::type() const {
    return m_userType == Auto ? m_autoType : m_userType;
}

Gpu::Type Gpu::userType() const {
    return m_userType;
}

Gpu::Type Gpu::autoType() const {
    return m_autoType;
}

QString Gpu::name() const {
    return m_name;
}

qreal Gpu::percentage() const {
    return m_percentage;
}

qreal Gpu::temperature() const {
    return m_temperature;
}

void Gpu::setUserType(Type value) {
    if (value == m_userType) {
        return;
    }
    const Type prevDerived = type();
    m_userType = value;
    emit userTypeChanged();
    if (type() != prevDerived) {
        emit typeChanged();
    }

    // Probe again when switching back to auto
    if (value == Auto) {
        detectGpu();
    }
}

void Gpu::setAutoType(Type value) {
    if (value == m_autoType) {
        return;
    }
    const Type prevDerived = type();
    m_autoType = value;
    emit autoTypeChanged();
    if (type() != prevDerived) {
        emit typeChanged();
    }
}

void Gpu::setName(QString value) {
    if (value == m_name) {
        return;
    }
    m_name = std::move(value);
    emit nameChanged();
}

void Gpu::tick() {
    const Type t = type();
    if (t == Generic) {
        readGenericUsage();
        readGpuTemperature();
    } else if (t == Nvidia) {
        startNvidiaUsage();
    } else {
        if (std::abs(m_percentage) > 0.0001) {
            m_percentage = 0.0;
            emit percentageChanged();
        }
        if (std::abs(m_temperature) > 0.05) {
            m_temperature = 0.0;
            emit temperatureChanged();
        }
    }
}

void Gpu::detectGpu() {
    if (m_detecting) {
        return;
    }
    m_detecting = true;

    // Probe in priority order, stopping at the first result
    tryNameSource(0);
}

void Gpu::tryNameSource(int index) {
    const NameSource& src = nameSources().at(static_cast<std::size_t>(index));
    runProcess(src.program, src.args, [this, index, parse = src.parse](const QByteArray& out) {
        finishNameSource(index, parse(out));
    });
}

void Gpu::finishNameSource(int index, QString name) {
    // The NVIDIA name probe doubles as the type probe: a non-empty result means an
    // NVIDIA GPU is present and queryable. Derive autoType unconditionally (even when
    // the user pins a type) so a later switch to Auto reads a correct value without
    // depending on its own re-probe, which is skipped while a probe is in flight.
    if (index == kNvidiaSource) {
        if (!name.isEmpty()) {
            setAutoType(Nvidia);
        } else if (!m_busyFiles.isEmpty()) {
            setAutoType(Generic);
        } else if (detectFdinfoGpu()) {
            setAutoType(Generic);
        } else {
            setAutoType(None);
        }
    }

    if (!name.isEmpty()) {
        setName(std::move(name));
        m_detecting = false;
        return;
    }

    if (index + 1 < static_cast<int>(nameSources().size())) {
        tryNameSource(index + 1);
    } else {
        m_detecting = false;
    }
}

void Gpu::runProcess(const QString& program, const QStringList& args, std::function<void(const QByteArray&)> callback) {
    auto* proc = new QProcess(this);
    proc->setStandardErrorFile(QProcess::nullDevice());

    // Deliver the result exactly once, then tear the process down. A crash or a
    // missing binary yields empty output so the caller can fall through gracefully:
    // only FailedToStart skips finished(), and a crash reports CrashExit there.
    const auto finish = [proc, callback = std::move(callback)](const QByteArray& out) {
        callback(out);
        proc->deleteLater();
    };

    QObject::connect(proc, &QProcess::finished, this, [finish, proc](int, QProcess::ExitStatus status) {
        finish(status == QProcess::NormalExit ? proc->readAllStandardOutput() : QByteArray());
    });
    QObject::connect(proc, &QProcess::errorOccurred, this, [finish](QProcess::ProcessError err) {
        if (err == QProcess::FailedToStart) {
            finish(QByteArray());
        }
    });

    proc->start(program, args);
}

bool Gpu::detectFdinfoGpu() const {
    // Check if any DRM card uses a driver that exposes fdinfo engine stats
    // (xe driver, or i915 on kernels 6.12+). These drivers don't expose
    // gpu_busy_percent but provide drm-cycles-* in /proc/*/fdinfo/.
    static const QRegularExpression cardRe(QStringLiteral("^card\\d+$"));

    QDirIterator it(QStringLiteral("/sys/class/drm"), QDir::Dirs | QDir::NoDotAndDotDot);
    while (it.hasNext()) {
        it.next();
        if (!cardRe.match(it.fileName()).hasMatch()) continue;

        const QString driverPath = it.filePath() + QStringLiteral("/device/driver");
        QFileInfo info(driverPath);
        if (!info.isSymlink()) continue;

        const QString target = info.symLinkTarget();
        // xe driver always uses fdinfo; i915 on kernels 6.12+ also supports it
        if (target.contains(QLatin1String("xe")) || target.contains(QLatin1String("i915"))) {
            return true;
        }
    }
    return false;
}

void Gpu::readGenericUsage() {
    // Fall back to fdinfo-based reading for drivers that don't expose
    // gpu_busy_percent (xe, newer i915).
    if (m_busyFiles.isEmpty()) {
        readFdinfoUsage();
        return;
    }

    qreal sum = 0.0;
    int count = 0;
    for (const QString& path : std::as_const(m_busyFiles)) {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        bool ok = false;
        const qreal v = f.readAll().trimmed().toDouble(&ok);
        f.close();
        if (ok) {
            sum += v;
            ++count;
        }
    }
    const qreal newPerc = count > 0 ? sum / count / 100.0 : 0.0;
    if (std::abs(newPerc - m_percentage) > 0.0001) {
        m_percentage = newPerc;
        emit percentageChanged();
    }
}

void Gpu::readFdinfoUsage() {
    // Read GPU utilization for drivers (xe, i915 6.12+) that expose engine
    // busy cycles via /proc/*/fdinfo/ instead of gpu_busy_percent in sysfs.
    // drm-cycles-<engine> / drm-total-cycles-<engine> gives the busy ratio.
    //
    // We scan processes with open DRM fds, aggregate drm-cycles-rcs across all
    // of them, and compute utilization as the delta between ticks.

    static QHash<QPair<pid_t, int>, QPair<qreal, qreal>> prevFdinfo;

    qreal totalDelta = 0.0;
    qreal busyDelta = 0.0;
    qreal capacity = 1.0;
    bool found = false;

    QSet<QPair<pid_t, int>> seen;

    QDir procDir(QStringLiteral("/proc"));
    const auto pids = procDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString& pidStr : pids) {
        bool ok = false;
        const pid_t pid = pidStr.toInt(&ok);
        if (!ok) continue;

        // Fast path: check for symlinks to /dev/dri/card* in fd/
        QDir fdDir(QStringLiteral("/proc/") + pidStr + QStringLiteral("/fd"));
        if (!fdDir.exists()) continue;

        const auto fds = fdDir.entryList(QDir::Files | QDir::System, QDir::Name);
        for (const QString& fdStr : fds) {
            const QString target = QFileInfo(fdDir.absoluteFilePath(fdStr)).symLinkTarget();
            if (!target.startsWith(QStringLiteral("/dev/dri/card"))) continue;

            ok = false;
            const int fdNum = fdStr.toInt(&ok);
            if (!ok) continue;

            QFile infoFile(QStringLiteral("/proc/") + pidStr + QStringLiteral("/fdinfo/") + fdStr);
            if (!infoFile.open(QIODevice::ReadOnly | QIODevice::Text)) continue;

            const auto content = infoFile.readAll();
            infoFile.close();

            if (!content.contains("drm-total-cycles-rcs")) continue;

            seen.insert({pid, fdNum});
            found = true;

            qreal total = 0.0, busy = 0.0, cap = 1.0;
            for (const QByteArray& line : content.split('\n')) {
                const QList<QByteArray> kv = line.split('\t');
                if (kv.size() != 2) continue;
                if (kv[0] == "drm-total-cycles-rcs") {
                    total = kv[1].trimmed().toDouble();
                } else if (kv[0] == "drm-cycles-rcs") {
                    busy = kv[1].trimmed().toDouble();
                } else if (kv[0] == "drm-engine-capacity-rcs") {
                    cap = kv[1].trimmed().toDouble();
                }
            }

            if (total > 0.0) {
                capacity = cap;
                const auto key = qMakePair(pid, fdNum);
                const auto it = prevFdinfo.constFind(key);
                if (it != prevFdinfo.constEnd()) {
                    const qreal dTotal = total - it->first;
                    const qreal dBusy = busy - it->second;
                    if (dTotal > 0.0) {
                        totalDelta = qMax(totalDelta, dTotal);
                        busyDelta += qMax(dBusy, 0.0);
                    }
                }
                prevFdinfo[key] = {total, busy};
            }
        }
    }

    // Remove stale entries (processes that no longer have these DRM fds)
    for (auto it = prevFdinfo.begin(); it != prevFdinfo.end();) {
        if (!seen.contains(it.key())) {
            it = prevFdinfo.erase(it);
        } else {
            ++it;
        }
    }

    if (found && totalDelta > 0.0) {
        const qreal newPerc = qMin(busyDelta / totalDelta / capacity, 1.0);
        if (std::abs(newPerc - m_percentage) > 0.0001) {
            m_percentage = newPerc;
            emit percentageChanged();
        }
    }
}

void Gpu::startNvidiaUsage() {
    if (m_nvidiaQuerying) {
        return;
    }
    m_nvidiaQuerying = true;
    runProcess(QStringLiteral("nvidia-smi"),
        { QStringLiteral("--query-gpu=utilization.gpu,temperature.gpu"),
            QStringLiteral("--format=csv,noheader,nounits") },
        [this](const QByteArray& out) {
            m_nvidiaQuerying = false;

            const QList<QByteArray> parts = out.trimmed().split(',');
            if (parts.size() < 2) {
                return;
            }
            bool ok1 = false;
            bool ok2 = false;
            const qreal usage = parts.at(0).trimmed().toDouble(&ok1) / 100.0;
            const qreal temp = parts.at(1).trimmed().toDouble(&ok2);
            if (ok1 && std::abs(usage - m_percentage) > 0.0001) {
                m_percentage = usage;
                emit percentageChanged();
            }
            if (ok2 && std::abs(temp - m_temperature) > 0.05) {
                m_temperature = temp;
                emit temperatureChanged();
            }
        });
}

void Gpu::readGpuTemperature() {
    const auto t = sensorslib::gpuPciAverageTemp();
    const qreal newTemp = t.value_or(0.0);
    if (std::abs(newTemp - m_temperature) > 0.05) {
        m_temperature = newTemp;
        emit temperatureChanged();
    }
}

Gpu::Type Gpu::parseType(const QString& s) {
    const QString u = s.trimmed().toUpper();
    if (u.isEmpty()) {
        return Auto;
    }
    if (u == QStringLiteral("NVIDIA")) {
        return Nvidia;
    }
    if (u == QStringLiteral("GENERIC")) {
        return Generic;
    }
    return None;
}

} // namespace caelestia::services
