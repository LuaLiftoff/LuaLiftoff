-- Only allow require global in files, all others should be required
std = {read_globals = {"require"}}
cache = true
include_files = {"**/*.lua", "*.rockspec", "*.luacheckrc", "*.busted", "*.luacov"}
self = false

-- Allow globals in spec files
files["spec/**/*.lua"].std = "+min"
