#!/usr/bin/env fish

set SCRIPT_DIR (dirname (status dirname))
set PATCH_DIR $SCRIPT_DIR/patches/caelestia-services
set BUILD_DIR /tmp/caelestia-build

echo "=== Cae-Mod: Build GPU plugin fix ==="

# Clone shell source if not present
if not test -d $BUILD_DIR
    echo "Cloning caelestia-dots/shell..."
    git clone --depth 1 https://github.com/caelestia-dots/shell.git $BUILD_DIR
else
    echo "Removing old build..."
    rm -rf $BUILD_DIR
    git clone --depth 1 https://github.com/caelestia-dots/shell.git $BUILD_DIR
end

# Apply patch
echo "Applying GPU xe driver fix..."
cp $PATCH_DIR/gpu.hpp $BUILD_DIR/plugin/src/Caelestia/Services/gpu.hpp
cp $PATCH_DIR/gpu.cpp $BUILD_DIR/plugin/src/Caelestia/Services/gpu.cpp

# Configure cmake (plugin only)
echo "Configuring cmake..."
cd $BUILD_DIR
set VERSION (pacman -Qi caelestia-shell 2>/dev/null | grep Version | awk '{print $3}')
if test -z "$VERSION"
    set VERSION "2.1.0"
end
cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_MODULES="plugin" \
    -DVERSION=$VERSION \
    -DINSTALL_QMLDIR="usr/lib/qt6/qml" \
    -DINSTALL_LIBDIR="usr/lib" \
    -DCMAKE_SKIP_RPATH=ON 2>&1 | tail -3

# Build
echo "Building..."
cmake --build build --target caelestia-servicesplugin -j(nproc) 2>&1 | tail -5

# Install
echo "Installing..."
sudo cp build/qml/Caelestia/Services/libcaelestia-servicesplugin.so /usr/lib/qt6/qml/Caelestia/Services/libcaelestia-servicesplugin.so

for lib in build/plugin/src/Caelestia/libcaelestia-core.so \
           build/plugin/src/Caelestia/Config/libcaelestia-config.so \
           build/plugin/src/Caelestia/Internal/libcaelestia-internal.so \
           build/plugin/src/Caelestia/Services/libcaelestia-services.so
    set basename (basename $lib)
    # Backup original
    if not test -f /usr/lib/qt6/qml/Caelestia/lib/$basename.bak
        sudo cp /usr/lib/qt6/qml/Caelestia/lib/$basename /usr/lib/qt6/qml/Caelestia/lib/$basename.bak
    end
    sudo cp $lib /usr/lib/qt6/qml/Caelestia/lib/$basename
end

# Fix RUNPATH on rebuilt libs
echo "Fixing RUNPATH..."
for lib in /usr/lib/qt6/qml/Caelestia/lib/libcaelestia-core.so \
           /usr/lib/qt6/qml/Caelestia/lib/libcaelestia-config.so \
           /usr/lib/qt6/qml/Caelestia/lib/libcaelestia-internal.so \
           /usr/lib/qt6/qml/Caelestia/lib/libcaelestia-services.so
    sudo patchelf --set-rpath '$ORIGIN:$ORIGIN/../lib' $lib
end
sudo patchelf --set-rpath '$ORIGIN:$ORIGIN/../lib' /usr/lib/qt6/qml/Caelestia/Services/libcaelestia-servicesplugin.so

# Verify
echo "Verifying..."
if ldd /usr/lib/qt6/qml/Caelestia/Services/libcaelestia-servicesplugin.so 2>&1 | grep -q "not found"
    echo "ERROR: Missing dependencies!"
    ldd /usr/lib/qt6/qml/Caelestia/Services/libcaelestia-servicesplugin.so 2>&1 | grep "not found"
    exit 1
else
    echo "All dependencies OK"
end

echo ""
echo "=== GPU plugin fix installed ==="
echo "Restart caelestia: caelestia shell -d"
