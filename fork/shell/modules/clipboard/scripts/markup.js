.pragma library

// Escape text for a StyledText label and wrap the characters fzf.js matched
// (positions index the NFC-normalised UTF-16 string, which is what it
// matched against) in the given colour, bold. Shared by the clipboard list and
// the link menu so both pick out matches the same way.
function highlighted(text, positions, colour) {
    const hits = new Set(positions);
    const chars = text.normalize().split("");
    const esc = ch => ch === "&" ? "&amp;" : ch === "<" ? "&lt;" : ch === ">" ? "&gt;" : ch;
    let out = "";
    let open = false;
    for (let i = 0; i < chars.length; i++) {
        const hit = hits.has(i);
        if (hit && !open)
            out += `<font color="${colour}"><b>`;
        else if (!hit && open)
            out += "</b></font>";
        open = hit;
        out += esc(chars[i]);
    }
    return open ? out + "</b></font>" : out;
}
