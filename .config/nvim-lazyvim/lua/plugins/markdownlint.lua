local config = {
  MD013 = {
    line_length = 120,
  },
}

--local config_path = vim.fn.stdpath("config") .. "/.markdownlint.json"
local config_path = ".markdownlint.json"
local file = io.open(config_path, "w")
if file then
  file:write(vim.json.encode(config))
  file:close()
end

return {
  "mfussenegger/nvim-lint",
  opts = {
    linters = {
      ["markdownlint-cli2"] = {
        args = {
          "--config",
          config_path,
          "-",
        },
      },
    },
  },
}
