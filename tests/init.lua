local MiniTest = require("mini.test")

MiniTest.setup({
  collect = {
    find_files = function()
      return vim.fn.globpath("tests", "test_*.lua", true, true)
    end,
    filter_cases = function(case)
      return true
    end,
  },
  execute = {
    reporter = MiniTest.gen_reporter.buffer({ window = { border = "rounded" } }),
  },
})

vim.keymap.set("n", "<leader>tr", function()
  MiniTest.run()
end, { desc = "Run all tests" })

vim.keymap.set("n", "<leader>tf", function()
  MiniTest.run_file()
end, { desc = "Run current file tests" })

vim.keymap.set("n", "<leader>tc", function()
  MiniTest.run_at_location()
end, { desc = "Run test at cursor" })
