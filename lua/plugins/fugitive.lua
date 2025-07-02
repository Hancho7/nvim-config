return {
	"tpope/vim-fugitive",
	cmd = { "G", "Git" }, -- Lazy-load only when needed
	keys = {
		{ "<leader>gs", "<cmd>Git<cr>", desc = "Fugitive: Status" },
		{ "<leader>gc", "<cmd>Git commit<cr>", desc = "Fugitive: Commit" },
		{ "<leader>gp", "<cmd>Git push<cr>", desc = "Fugitive: Push" },
		{ "<leader>gb", "<cmd>Git blame<cr>", desc = "Fugitive: Blame" },
	},
}
