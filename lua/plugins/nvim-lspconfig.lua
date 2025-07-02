return {
	{
		-- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
		-- used for completion, annotations and signatures of Neovim apis
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				-- Load luvit types when the `vim.uv` word is found
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},
	{
		-- Main LSP Configuration
		"neovim/nvim-lspconfig",
		dependencies = {
			{ "williamboman/mason.nvim", opts = {} },
			"williamboman/mason-lspconfig.nvim",
			-- Removed mason-tool-installer to avoid the error

			-- Useful status updates for LSP.
			{ "j-hui/fidget.nvim", opts = {} },

			-- Allows extra capabilities provided by blink.cmp
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			-- LSP Attach function (same as before)
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = function(event)
					local map = function(keys, func, desc, mode)
						mode = mode or "n"
						vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end

					-- All your existing keybindings...
					map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
					map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
					map("<leader>gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
					map("<leader>gi", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
					map("<leader>gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
					map("<leader>gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
					map("<leader>gO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")
					map("<leader>gW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Open Workspace Symbols")
					map("<leader>gt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")

					-- Java-specific keymaps
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if client and client.name == "jdtls" then
						map("<leader>jo", function() require("jdtls").organize_imports() end, "[J]ava [O]rganize imports")
						map("<leader>jv", function() require("jdtls").extract_variable() end, "[J]ava Extract [V]ariable")
						map("<leader>jc", function() require("jdtls").extract_constant() end, "[J]ava Extract [C]onstant")
						map("<leader>jm", function() require("jdtls").extract_method(true) end, "[J]ava Extract [M]ethod", "v")
						map("<leader>ju", function() require("jdtls").update_projects_config() end, "[J]ava [U]pdate project config")
					end

					-- Client support method function
					local function client_supports_method(client, method, bufnr)
						if vim.fn.has("nvim-0.11") == 1 then
							return client:supports_method(method, bufnr)
						else
							return client.supports_method(method, { bufnr = bufnr })
						end
					end

					-- Document highlighting
					if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
						local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
							end,
						})
					end

					-- Inlay hints toggle
					if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
						map("<leader>th", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
						end, "[T]oggle Inlay [H]ints")
					end
				end,
			})

			-- Diagnostic Config
			vim.diagnostic.config({
				severity_sort = true,
				float = { border = "rounded", source = "if_many" },
				underline = { severity = vim.diagnostic.severity.ERROR },
				signs = vim.g.have_nerd_font and {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.INFO] = "󰋽 ",
						[vim.diagnostic.severity.HINT] = "󰌶 ",
					},
				} or {},
				virtual_text = {
					source = "if_many",
					spacing = 2,
					format = function(diagnostic)
						return diagnostic.message
					end,
				},
			})

			-- Capabilities setup
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- Server configurations
			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							completion = { callSnippet = "Replace" },
						},
					},
				},
				ts_ls = {},
				yamlls = {
					settings = {
						yaml = {
							schemas = {
								["kubernetes"] = "*.k8s.yaml",
								["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
							},
							validate = true,
							completion = true,
							hover = true,
						},
					},
				},
				jdtls = {
					cmd = { "jdtls" },
					root_dir = require("lspconfig.util").root_pattern(".git", "mvnw", "gradlew", "pom.xml", "build.gradle", "build.gradle.kts"),
					settings = {
						java = {
							configuration = {
								runtimes = {
									{ name = "JavaSE-17", path = "/usr/lib/jvm/java-17-openjdk-amd64/" },
									{ name = "JavaSE-21", path = "/usr/lib/jvm/java-21-openjdk-amd64/" },
								},
							},
							eclipse = { downloadSources = true },
							maven = { downloadSources = true },
							implementationsCodeLens = { enabled = true },
							referencesCodeLens = { enabled = true },
							references = { includeDecompiledSources = true },
							format = {
								enabled = true,
								settings = {
									url = vim.fn.stdpath("config") .. "/lang-servers/intellij-java-google-style.xml",
									profile = "GoogleStyle",
								},
							},
							signatureHelp = { enabled = true },
							contentProvider = { preferred = "fernflower" },
							completion = {
								favoriteStaticMembers = {
									"org.hamcrest.MatcherAssert.assertThat",
									"org.hamcrest.Matchers.*",
									"org.hamcrest.CoreMatchers.*",
									"org.junit.jupiter.api.Assertions.*",
									"java.util.Objects.requireNonNull",
									"java.util.Objects.requireNonNullElse",
									"org.mockito.Mockito.*",
								},
								importOrder = { "java", "javax", "com", "org" },
							},
							sources = {
								organizeImports = {
									starThreshold = 9999,
									staticStarThreshold = 9999,
								},
							},
							codeGeneration = {
								toString = {
									template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
								},
								useBlocks = true,
							},
						},
					},
					flags = { allow_incremental_sync = true },
					init_options = { bundles = {} },
				},
			}

			-- Setup Mason and mason-lspconfig
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = vim.tbl_keys(servers),
				automatic_installation = true,
				handlers = {
					function(server_name)
						local server = servers[server_name] or {}
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
				},
			})
		end,
	},
}
