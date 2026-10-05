--[[---------------------------------------------------------------------------
    Glyphic - TonguesOfAzeroth/Shim.lua

    This folder is not an addon so much as a key to a filing cabinet.

    Until 0.5.3 this addon lived in a folder called TonguesOfAzeroth, and WoW
    names a saved variables file after the folder: every existing player's
    languages, fluency, colors, custom tongues and cast phrases are sitting in
    WTF\...\SavedVariables\TonguesOfAzeroth.lua. The client only reads that
    file if some enabled addon declares the variables inside it. Renaming the
    folder to Glyphic would therefore have left all of it on disk, intact and
    unreachable, and every upgrade would have looked like a fresh install.

    So this folder stays behind to declare those two globals and nothing else.
    Its TOC is what does the work. Core.lua adopts the tables at file scope and
    clears them, which drains the old file to nil on the next logout, and
    `## OptionalDeps: TonguesOfAzeroth` on Glyphic's TOCs is what guarantees
    this has loaded first.

    There is no code here on purpose: an empty addon has no bugs. The file
    exists only because a TOC that lists no files is a less well-trodden path
    than one that lists a file doing nothing, and this is not the place to find
    out which clients disagree.

    Retiring it: one major release after the rename. By then anyone still on a
    pre-0.5.3 profile has not launched the game in months, and the cost of
    being wrong is their settings rather than a crash -- so when it goes, it
    should go in a release whose notes say so plainly.
------------------------------------------------------------------------------]]
