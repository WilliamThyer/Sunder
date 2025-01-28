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
        27, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 28,
        83, 0, 2226, 2227, 0, 0, 0, 0, 0, 0, 0, 0, 0, 71, 21, 85,
        83, 0, 0, 0, 0, 0, 285, 286, 0, 0, 0, 236, 0, 71, 47, 85,
        83, 0, 0, 271, 0, 0, 311, 177, 0, 0, 0, 0, 543, 151, 0, 85,
        83, 0, 0, 297, 0, 0, 0, 0, 0, 0, 0, 0, 486, 0, 0, 85,
        83, 0, 0, 323, 0, 0, 0, 0, 0, 337, 338, 0, 323, 0, 0, 85,
        83, 1499, 1500, 349, 0, 0, 1209, 1210, 0, 0, 0, 0, 349, 1301, 0, 85,
        53, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 108, 54,
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
      visible = true,
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
