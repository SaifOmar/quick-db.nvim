# quick-db.nvim
Database access for quick devs.

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua

{
  "SaifOmar/quick-db.nvim",
  dependencies = {
      'nvim-telescope/telescope.nvim',
  },
  config = function()
    require("quick-db")
  end,
}


## 📝 Commands

  `:QuickConnect` – Magic command to connect to a database and start your fast dev session.

  `:QuickConnectUserConnection` –  Allows users to specify their own connection.

```
