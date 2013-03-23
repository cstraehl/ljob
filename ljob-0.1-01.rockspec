 --
-- Lanes rockspec
--
-- Ref:
--      <http://luarocks.org/en/Rockspec_format>
--

package = "ljob"

version = "0.1-01"

source= {
    url = "http://github.com"
}

description = {
	summary= "Multiprocessing support for Luajit",
	detailed= [[
            ljob is a easy to use fork systemcall based parallel processing library.
	]],
	license= "MIT/X11",
	homepage="https://github.com/cstraehl/ljob",
	maintainer="Christoph Straehle <cstraehle@gmail.com>"
}

supported_platforms= { 
					   "macosx",    -- TBD: not tested
					   "linux",
					   "freebsd",   -- TBD: not tested
}

dependencies= {
	"lua >= 5.1", -- builds with either 5.1 and 5.2
}

build = {
	type = "builtin",
	platforms =
	{
		linux =
		{
			modules =
			{
				["ljob.marshal"] =
				{
				},
			}
		}
	},
	modules =
	{
                ["ljob.init"] = "init.lua",
		["ljob.marshal"] =
		{
			sources = { "lmarshal.c"},
			incdirs = { },
		}
	}
}

