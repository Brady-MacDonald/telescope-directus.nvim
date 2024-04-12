# Telescope Directus Extension

Browse Directus Collections/Fields/Items using Telescope

## Setup

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
    end
}
```

## Config

## Use

## Default Mappings

Mappings set inside Telescope

| Mappings       | Action                                                    |
| -------------- | --------------------------------------------------------- |
| `<c>`          | Open Directus Collections                                 |
| `<f>`          | Open Directus Fields                                      |

