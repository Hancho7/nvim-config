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
			"WhoIsSethDaniel/mason-tool-installer.nvim",

			-- Useful status updates for LSP.
			{ "j-hui/fidget.nvim", opts = {} },

			-- Allows extra capabilities provided by nvim-cmp
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			--  This function gets run when an LSP attaches to a particular buffer.
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = function(event)
					local map = function(keys, func, desc, mode)
						mode = mode or "n"
						vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end

					-- Rename the variable under your cursor.
					map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

					-- Execute a code action, usually your cursor needs to be on top of an error
					map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })

					-- Find references for the word under your cursor.
					map("<leader>gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")

					-- Jump to the implementation of the word under your cursor.
					map("<leader>gi", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

					-- Jump to the definition of the word under your cursor.
					map("<leader>gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")

					-- WARN: This is not Goto Definition, this is Goto Declaration.
					map("<leader>gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

					-- Fuzzy find all the symbols in your current document.
					map("<leader>gO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")

					-- Fuzzy find all the symbols in your current workspace.
					map(
						"<leader>gW",
						require("telescope.builtin").lsp_dynamic_workspace_symbols,
						"Open Workspace Symbols"
					)

					-- Jump to the type of the word under your cursor.
					map("<leader>gt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")

					-- Java-specific keymaps (only active for Java files)
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if client and client.name == "jdtls" then
						map("<leader>jo", function()
							require("jdtls").organize_imports()
						end, "[J]ava [O]rganize imports")

						map("<leader>jv", function()
							require("jdtls").extract_variable()
						end, "[J]ava Extract [V]ariable")

						map("<leader>jc", function()
							require("jdtls").extract_constant()
						end, "[J]ava Extract [C]onstant")

						map("<leader>jm", function()
							require("jdtls").extract_method(true)
						end, "[J]ava Extract [M]ethod", "v")

						map("<leader>ju", function()
							require("jdtls").update_projects_config()
						end, "[J]ava [U]pdate project config")
					end

					-- This function resolves a difference between neovim versions
					local function client_supports_method(client, method, bufnr)
						if vim.fn.has("nvim-0.11") == 1 then
							return client:supports_method(method, bufnr)
						else
							return client.supports_method(method, { bufnr = bufnr })
						end
					end

					-- Document highlight setup
					if
						client
						and client_supports_method(
							client,
							vim.lsp.protocol.Methods.textDocument_documentHighlight,
							event.buf
						)
					then
						local highlight_augroup =
							vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
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
					if
						client
						and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf)
					then
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

			-- Get capabilities from nvim-cmp
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- Enable the following language servers (REMOVED jdtls from here)
			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
							-- Make the server aware of Neovim runtime files
							diagnostics = {
								globals = { "vim" },
							},
							workspace = {
								library = vim.api.nvim_get_runtime_file("", true),
								checkThirdParty = false,
							},
							telemetry = { enable = false },
						},
					},
				},
				ts_ls = {},
				-- YAML Language Server
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
				-- NOTE: jdtls is handled separately by nvim-jdtls plugin
			}

			-- Ensure the servers and tools above are installed
			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, {
				"stylua",
				"google-java-format",
				"prettier",
				"jdtls", -- Still install jdtls through mason
			})
			require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

			require("mason-lspconfig").setup({
				ensure_installed = {},
				automatic_installation = true,
				handlers = {
					function(server_name)
						-- Skip jdtls as it's handled by nvim-jdtls
						if server_name == "jdtls" then
							return
						end

						local server = servers[server_name] or {}
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
				},
			})
		end,
	},
	{
		-- Java LSP Configuration
		"mfussenegger/nvim-jdtls",
		ft = "java",
		config = function()
			-- Function to find the Java project root
			local function find_java_project_root(path)
				local markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle", "build.gradle.kts" }
				local root = vim.fs.find(markers, { path = path, upward = true })
				return root and vim.fs.dirname(root[1]) or vim.fn.getcwd()
			end

			-- Setup jdtls when Java files are opened
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "java",
				callback = function()
					local jdtls = require("jdtls")
					local capabilities = require("cmp_nvim_lsp").default_capabilities()

					-- Get the current file path and find project root
					local current_file = vim.api.nvim_buf_get_name(0)
					local project_root = find_java_project_root(current_file)

					-- Create a unique workspace name based on the project root
					local workspace_name = vim.fn.fnamemodify(project_root, ":p:h:t")
					local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. workspace_name

					-- Lombok JAR path
					local lombok_jar = vim.fn.stdpath("data") .. "/mason/packages/jdtls/lombok.jar"

					-- JDTLS configuration
					local config = {
						cmd = {
							vim.fn.stdpath("data") .. "/mason/bin/jdtls",
							"-configuration",
							vim.fn.stdpath("cache") .. "/jdtls/config",
							"-data",
							workspace_dir,
							"-Declipse.application=org.eclipse.jdt.ls.core.id1",
							"-Dosgi.bundles.defaultStartLevel=4",
							"-Declipse.product=org.eclipse.jdt.ls.core.product",
							"-Dlog.protocol=true",
							"-Dlog.level=ALL",
							"-Xmx1g",
							"--add-modules=ALL-SYSTEM",
							"--add-opens",
							"java.base/java.util=ALL-UNNAMED",
							"--add-opens",
							"java.base/java.lang=ALL-UNNAMED",
							-- Add Lombok agent if the JAR exists
							vim.fn.filereadable(lombok_jar) == 1 and ("-javaagent:" .. lombok_jar) or nil,
						},
						root_dir = project_root,
						capabilities = capabilities,
						settings = {
							java = {
								eclipse = {
									downloadSources = true,
								},
								maven = {
									downloadSources = true,
								},
								implementationsCodeLens = {
									enabled = true,
								},
								referencesCodeLens = {
									enabled = true,
								},
								references = {
									includeDecompiledSources = true,
								},
								format = {
									enabled = true,
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
									importOrder = {
										"java",
										"javax",
										"com",
										"org",
									},
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
								configuration = {
									runtimes = {
										{
											name = "JavaSE-17",
											path = "/usr/lib/jvm/java-17-openjdk-amd64/",
										},
										{
											name = "JavaSE-21",
											path = "/usr/lib/jvm/java-21-openjdk-amd64/",
										},
									},
								},
							},
						},
						init_options = {
							bundles = {},
						},
						flags = {
							allow_incremental_sync = true,
						},
					}

					-- Start jdtls
					jdtls.start_or_attach(config)
				end,
			})
		end,
	},
}
