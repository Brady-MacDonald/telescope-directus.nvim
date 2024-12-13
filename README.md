<div align="center">

# Telescope Directus Extension
##### Browse Directus collections/fields/items using telescope

[![Telescope](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](https://github.com/nvim-telescope/telescope.nvim)
[![Directus](https://user-images.githubusercontent.com/522079/158864859-0fbeae62-9d7a-4619-b35e-f8fa5f68e0c8.png)](https://github.com/directus/directus)

<img alt="Telescope Directus Alt" height="280" src="/assets/directus-icon.png" />
</div>

## TOC
* [Setup](#Setup)
* [API](#-API)
    * [Config](#config)
    * [Settings](#settings)
    * [Defaults](#defaults)

## Setup

Requires a url and token with proper credentials
`show_hidden` field is optional to control the fields which are shown

```lua
return {
    "Brady-MacDonald/telescope-directus.nvim",
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
        local directus = require("directus")

        directus.setup({
            url = "http://localhost:8055",
            token = "1234",
            show_hidden = true
        })

        vim.keymap.set("n", "<leader>dc", directus.directus_collections, { desc = "Directus Collection" })
    end
}
```

## API

### User Commands

User commands offer tab completion

```sh
    :Directus collections
    :Directus fields <collection>
```

## Default Key Maps

Mappings set inside Telescope

| Mapping   | Location     | Action                                    |
| --------- | ------------ | ----------------------------------------- |
| `<CR>`    | Collections  | Open query for selected collection        |
| `<f>`     | Collections  | Open Directus Fields for the given collection  |

