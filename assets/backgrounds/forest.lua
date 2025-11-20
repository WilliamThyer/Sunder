return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.11.1.1",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 16,
  height = 9,
  tilewidth = 8,
  tileheight = 8,
  nextlayerid = 5,
  nextobjectid = 1,
  backgroundcolor = { 0, 0, 0 },
  properties = {},
  tilesets = {
    {
      name = "Underground",
      firstgid = 1,
      class = "",
      tilewidth = 8,
      tileheight = 8,
      spacing = 0,
      margin = 0,
      columns = 26,
      image = "Underground.png",
      imagewidth = 208,
      imageheight = 344,
      transparentcolor = "#000000",
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 8,
        height = 8
      },
      properties = {},
      wangsets = {},
      tilecount = 1118,
      tiles = {}
    },
    {
      name = "Overworld",
      firstgid = 1119,
      class = "",
      tilewidth = 8,
      tileheight = 8,
      spacing = 0,
      margin = 0,
      columns = 35,
      image = "Overworld.png",
      imagewidth = 280,
      imageheight = 256,
      transparentcolor = "#000000",
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 8,
        height = 8
      },
      properties = {},
      wangsets = {},
      tilecount = 1120,
      tiles = {
        {
          id = 436,
          properties = {
            ["collidable"] = true
          }
        }
      }
    },
    {
      name = "Underground",
      firstgid = 2239,
      class = "",
      tilewidth = 32,
      tileheight = 32,
      spacing = 0,
      margin = 0,
      columns = 0,
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 32,
        height = 32
      },
      properties = {},
      wangsets = {},
      tilecount = 0,
      tiles = {}
    },
    {
      name = "Overworld",
      firstgid = 2239,
      class = "",
      tilewidth = 32,
      tileheight = 32,
      spacing = 0,
      margin = 0,
      columns = 0,
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 32,
        height = 32
      },
      properties = {},
      wangsets = {},
      tilecount = 0,
      tiles = {}
    },
    {
      name = "Foliage",
      firstgid = 2239,
      class = "",
      tilewidth = 8,
      tileheight = 8,
      spacing = 0,
      margin = 0,
      columns = 24,
      image = "Chroma Noir/Chroma-Noir-Jungle-Documented-8x8/Foliage.png",
      imagewidth = 192,
      imageheight = 320,
      transparentcolor = "#000000",
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 8,
        height = 8
      },
      properties = {},
      wangsets = {},
      tilecount = 960,
      tiles = {}
    },
    {
      name = "Overworld",
      firstgid = 3199,
      class = "",
      tilewidth = 8,
      tileheight = 8,
      spacing = 0,
      margin = 0,
      columns = 57,
      image = "Chroma Noir/Chroma-Noir-Jungle-Documented-8x8/Overworld.png",
      imagewidth = 456,
      imageheight = 312,
      transparentcolor = "#000000",
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 8,
        height = 8
      },
      properties = {},
      wangsets = {},
      tilecount = 2223,
      tiles = {}
    },
    {
      name = "Trees",
      firstgid = 5422,
      class = "",
      tilewidth = 8,
      tileheight = 8,
      spacing = 0,
      margin = 0,
      columns = 102,
      image = "Chroma Noir/Chroma-Noir-Jungle-Documented-8x8/Trees.png",
      imagewidth = 816,
      imageheight = 576,
      transparentcolor = "#000000",
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 8,
        height = 8
      },
      properties = {},
      wangsets = {},
      tilecount = 7344,
      tiles = {}
    }
  },
  layers = {
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 16,
      height = 9,
      id = 4,
      name = "bg",
      class = "",
      visible = false,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 6101, 6102, 6103, 0, 0, 6617, 6618, 6619, 6620, 6621, 0, 0, 0, 0, 0,
        0, 6203, 6204, 6205, 0, 0, 6719, 10785, 6721, 6722, 6723, 0, 0, 0, 0, 6103,
        0, 10791, 6306, 6307, 0, 0, 6821, 10887, 6823, 6824, 8033, 0, 8441, 8142, 8442, 8443,
        0, 10893, 6408, 6409, 0, 0, 10988, 10989, 10990, 0, 0, 0, 8543, 10791, 8544, 8545,
        0, 10995, 10996, 0, 0, 0, 11090, 11091, 11092, 0, 0, 0, 0, 10995, 10996, 6409,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11090, 11091, 11092, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      }
    },
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 16,
      height = 9,
      id = 1,
      name = "Tile Layer 1",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      data = {
        3259, 3272, 3273, 3274, 3310, 3311, 3300, 3301, 3302, 3303, 3304, 3305, 3292, 8813, 8815, 8816,
        10839, 3329, 3330, 3331, 3367, 3368, 3357, 3358, 3359, 3360, 3361, 3362, 0, 0, 8917, 8918,
        10941, 3386, 3387, 3388, 3424, 3425, 0, 0, 0, 0, 0, 0, 0, 0, 9076, 10743,
        11043, 3443, 3444, 3445, 3481, 3482, 0, 0, 0, 0, 0, 0, 9176, 0, 9178, 10845,
        10830, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10947,
        11037, 0, 2778, 2779, 2780, 0, 0, 0, 0, 0, 0, 2769, 2770, 2771, 0, 11049,
        11349, 0, 2802, 2803, 2609, 2610, 0, 0, 0, 0, 0, 2793, 2794, 2795, 0, 11355,
        573, 2817, 2826, 2632, 2828, 2817, 2817, 2817, 2817, 2817, 2817, 2817, 2818, 2819, 2630, 573,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      }
    },
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 16,
      height = 9,
      id = 2,
      name = "collision",
      class = "",
      visible = false,
      opacity = 0,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      data = {
        1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555,
        1555, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1555,
        1555, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1555,
        1555, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1555,
        1555, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1555,
        1555, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1555,
        1555, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1555,
        1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555, 1555,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      }
    }
  }
}
