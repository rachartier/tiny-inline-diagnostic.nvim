local function ensure_installed(plugin)
  local install_path = vim.fn.stdpath("data") .. "/site/pack/deps/start/" .. plugin
  if vim.fn.isdirectory(install_path) == 0 then
    vim.notify("Installing " .. plugin, vim.log.levels.INFO)
    vim.fn.system({
      "git",
      "clone",
      "--depth=1",
      "https://github.com/nvim-mini/" .. plugin .. ".git",
      install_path,
    })
    vim.cmd("packloadall!")
  end
end

ensure_installed("mini.test")

vim.opt.runtimepath:append(vim.fn.getcwd())

vim.cmd("runtime! plugin/**/*.vim")
