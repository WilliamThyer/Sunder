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
  nextlayerid = 3,
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
      name = "Extras",
      firstgid = 2239,
      class = "",
      tilewidth = 8,
      tileheight = 8,
      spacing = 0,
      margin = 0,
      columns = 23,
      image = "Chroma Noir/Chroma-Noir-8x8/Extras.png",
      imagewidth = 184,
      imageheight = 80,
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
      tilecount = 230,
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
        209, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 209,
        271, 2195, 2226, 2227, 2233, 0, 0, 0, 0, 1642, 0, 2393, 2394, 2395, 73, 271,
        299, 0, 0, 0, 0, 0, 285, 286, 0, 0, 0, 2416, 2417, 2418, 99, 297,
        325, 0, 0, 317, 262, 0, 311, 0, 0, 0, 0, 2439, 2440, 2441, 0, 323,
        299, 0, 0, 343, 376, 0, 0, 0, 0, 0, 0, 0, 0, 0, 371, 299,
        325, 0, 0, 317, 411, 133, 0, 0, 0, 337, 338, 0, 0, 0, 0, 325,
        349, 1499, 1500, 0, 133, 1769, 1776, 1777, 0, 0, 0, 0, 0, 2019, 0, 349,
        210, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 210,
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
      opacity = 0.19,
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
