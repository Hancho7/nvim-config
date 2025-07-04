-- lua/plugins/java-boilerplate.lua
return {
	name = "java-boilerplate",
	dir = vim.fn.stdpath("config"),
	ft = "java",
	config = function()
		local M = {}

		-- Helper function to get current buffer lines
		local function get_buffer_lines()
			return vim.api.nvim_buf_get_lines(0, 0, -1, false)
		end

		-- Helper function to set buffer lines
		local function set_buffer_lines(lines)
			vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		end

		-- Helper function to find class definition
		local function find_class_info()
			local lines = get_buffer_lines()
			local class_name = nil
			local class_line = nil
			local fields = {}
			local last_field_line = nil

			for i, line in ipairs(lines) do
				-- Find class declaration
				local class_match = line:match("class%s+(%w+)")
				if class_match then
					class_name = class_match
					class_line = i
				end

				-- Find field declarations
				local field_match = line:match("^%s*private%s+([%w<>]+)%s+([%w_]+);")
				if field_match then
					local field_type, field_name = line:match("^%s*private%s+([%w<>]+)%s+([%w_]+);")
					table.insert(fields, {
						type = field_type,
						name = field_name,
						line = i,
					})
					last_field_line = i
				end
			end

			return {
				class_name = class_name,
				class_line = class_line,
				fields = fields,
				last_field_line = last_field_line or class_line,
			}
		end

		-- Helper function to find insertion point for methods
		local function find_method_insertion_point()
			local lines = get_buffer_lines()
			local class_info = find_class_info()

			-- Look for existing methods or end of class
			for i = class_info.last_field_line + 1, #lines do
				local line = lines[i]
				if line:match("^%s*public%s+") or line:match("^%s*private%s+") or line:match("^%s*protected%s+") then
					return i - 1
				end
				if line:match("^%s*}%s*$") then
					return i - 1
				end
			end

			return #lines
		end

		-- Generate getter method
		local function generate_getter(field)
			local getter_name = "get" .. field.name:sub(1, 1):upper() .. field.name:sub(2)
			return {
				"",
				"    public " .. field.type .. " " .. getter_name .. "() {",
				"        return " .. field.name .. ";",
				"    }",
			}
		end

		-- Generate setter method
		local function generate_setter(field)
			local setter_name = "set" .. field.name:sub(1, 1):upper() .. field.name:sub(2)
			return {
				"",
				"    public void " .. setter_name .. "(" .. field.type .. " " .. field.name .. ") {",
				"        this." .. field.name .. " = " .. field.name .. ";",
				"    }",
			}
		end

		-- Generate constructor
		local function generate_constructor(class_name, fields)
			local constructor = {
				"",
				"    public " .. class_name .. "() {",
				"    }",
				"",
			}

			if #fields > 0 then
				local params = {}
				local assignments = {}

				for _, field in ipairs(fields) do
					table.insert(params, field.type .. " " .. field.name)
					table.insert(assignments, "        this." .. field.name .. " = " .. field.name .. ";")
				end

				table.insert(constructor, "    public " .. class_name .. "(" .. table.concat(params, ", ") .. ") {")
				for _, assignment in ipairs(assignments) do
					table.insert(constructor, assignment)
				end
				table.insert(constructor, "    }")
			end

			return constructor
		end

		-- Generate toString method
		local function generate_tostring(class_name, fields)
			local method = {
				"",
				"    @Override",
				"    public String toString() {",
			}

			if #fields == 0 then
				table.insert(method, '        return "' .. class_name .. '{}";')
			else
				local field_strings = {}
				for _, field in ipairs(fields) do
					table.insert(field_strings, '"' .. field.name .. '=" + ' .. field.name)
				end

				table.insert(method, '        return "' .. class_name .. '{" +')
				for i, field_str in ipairs(field_strings) do
					local separator = (i < #field_strings) and ' ", " +' or ' "}";'
					table.insert(method, "                " .. field_str .. " +" .. separator)
				end
			end

			table.insert(method, "    }")
			return method
		end

		-- Generate equals and hashCode methods
		local function generate_equals_hashcode(class_name, fields)
			local methods = {
				"",
				"    @Override",
				"    public boolean equals(Object obj) {",
				"        if (this == obj) return true;",
				"        if (obj == null || getClass() != obj.getClass()) return false;",
				"        " .. class_name .. " that = (" .. class_name .. ") obj;",
			}

			if #fields == 0 then
				table.insert(methods, "        return true;")
			else
				local conditions = {}
				for _, field in ipairs(fields) do
					if field.type == "String" or field.type:match("^[A-Z]") then
						table.insert(conditions, "Objects.equals(" .. field.name .. ", that." .. field.name .. ")")
					else
						table.insert(conditions, field.name .. " == that." .. field.name)
					end
				end
				table.insert(methods, "        return " .. table.concat(conditions, " && ") .. ";")
			end

			table.insert(methods, "    }")
			table.insert(methods, "")
			table.insert(methods, "    @Override")
			table.insert(methods, "    public int hashCode() {")

			if #fields == 0 then
				table.insert(methods, "        return 0;")
			else
				local field_names = {}
				for _, field in ipairs(fields) do
					table.insert(field_names, field.name)
				end
				table.insert(methods, "        return Objects.hash(" .. table.concat(field_names, ", ") .. ");")
			end

			table.insert(methods, "    }")
			return methods
		end

		-- Generate builder pattern
		local function generate_builder(class_name, fields)
			local builder = {
				"",
				"    public static class Builder {",
			}

			-- Builder fields
			for _, field in ipairs(fields) do
				table.insert(builder, "        private " .. field.type .. " " .. field.name .. ";")
			end

			table.insert(builder, "")

			-- Builder methods
			for _, field in ipairs(fields) do
				local method_name = field.name
				table.insert(
					builder,
					"        public Builder " .. method_name .. "(" .. field.type .. " " .. field.name .. ") {"
				)
				table.insert(builder, "            this." .. field.name .. " = " .. field.name .. ";")
				table.insert(builder, "            return this;")
				table.insert(builder, "        }")
				table.insert(builder, "")
			end

			-- Build method
			table.insert(builder, "        public " .. class_name .. " build() {")
			table.insert(builder, "            return new " .. class_name .. "(" .. table.concat(
				vim.tbl_map(function(f)
					return f.name
				end, fields),
				", "
			) .. ");")
			table.insert(builder, "        }")
			table.insert(builder, "    }")
			table.insert(builder, "")
			table.insert(builder, "    public static Builder builder() {")
			table.insert(builder, "        return new Builder();")
			table.insert(builder, "    }")

			return builder
		end

		-- Insert methods at the appropriate location
		local function insert_methods(methods)
			local lines = get_buffer_lines()
			local insertion_point = find_method_insertion_point()

			-- Insert the new methods
			for i = #methods, 1, -1 do
				table.insert(lines, insertion_point + 1, methods[i])
			end

			set_buffer_lines(lines)
		end

		-- Show multi-select field selection UI
		local function select_fields(fields, prompt, callback)
			local choices = {}

			-- Add field choices
			for i, field in ipairs(fields) do
				table.insert(choices, {
					text = string.format("%d. %s %s", i, field.type, field.name),
					selected = false,
					field = field,
				})
			end

			local function update_display()
				local display_lines = { prompt, "" }
				for _, choice in ipairs(choices) do
					local prefix = choice.selected and "[✓] " or "[ ] "
					display_lines[#display_lines + 1] = prefix .. choice.text
				end
				display_lines[#display_lines + 1] = ""
				display_lines[#display_lines + 1] =
					"Controls: <Space>/<Enter> toggle, 'a' select all, 'n' none, 'd' done, 'q'/<Esc> quit"
				return display_lines
			end

			local function toggle_field(idx)
				if idx >= 1 and idx <= #choices then
					choices[idx].selected = not choices[idx].selected
				end
			end

			local function select_all()
				for _, choice in ipairs(choices) do
					choice.selected = true
				end
			end

			local function select_none()
				for _, choice in ipairs(choices) do
					choice.selected = false
				end
			end

			local function get_selected_fields()
				local selected = {}
				for _, choice in ipairs(choices) do
					if choice.selected and choice.field then
						table.insert(selected, choice.field)
					end
				end
				return selected
			end

			-- Create a scratch buffer for the selection UI
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
			vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
			vim.api.nvim_buf_set_option(buf, "modifiable", true)

			local width = 70
			local height = #choices + 6
			local row = math.floor(((vim.o.lines - height) / 2) - 1)
			local col = math.floor((vim.o.columns - width) / 2)

			local win = vim.api.nvim_open_win(buf, true, {
				relative = "editor",
				width = width,
				height = height,
				row = row,
				col = col,
				style = "minimal",
				border = "rounded",
			})

			-- Initial display
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, update_display())

			-- Helper function to get field index from cursor position
			local function get_field_index_from_cursor()
				local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
				-- Account for the prompt line and empty line (lines 1 and 2)
				local field_index = cursor_row - 2
				if field_index >= 1 and field_index <= #choices then
					return field_index
				end
				return nil
			end

			-- Key mappings for the selection window
			vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
				callback = function()
					local field_idx = get_field_index_from_cursor()
					if field_idx then
						toggle_field(field_idx)
						vim.api.nvim_buf_set_lines(buf, 0, -1, false, update_display())
					end
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "<Space>", "", {
				callback = function()
					local field_idx = get_field_index_from_cursor()
					if field_idx then
						toggle_field(field_idx)
						vim.api.nvim_buf_set_lines(buf, 0, -1, false, update_display())
					end
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "a", "", {
				callback = function()
					select_all()
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, update_display())
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "A", "", {
				callback = function()
					select_all()
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, update_display())
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "n", "", {
				callback = function()
					select_none()
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, update_display())
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "N", "", {
				callback = function()
					select_none()
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, update_display())
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
				callback = function()
					vim.api.nvim_win_close(win, true)
					callback({}) -- Return empty selection
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
				callback = function()
					vim.api.nvim_win_close(win, true)
					callback({}) -- Return empty selection
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "Q", "", {
				callback = function()
					vim.api.nvim_win_close(win, true)
					callback({}) -- Return empty selection
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "d", "", {
				callback = function()
					vim.api.nvim_win_close(win, true)
					local selected = get_selected_fields()
					callback(selected)
				end,
			})

			vim.api.nvim_buf_set_keymap(buf, "n", "D", "", {
				callback = function()
					vim.api.nvim_win_close(win, true)
					local selected = get_selected_fields()
					callback(selected)
				end,
			})

			-- Move cursor to first field option
			vim.api.nvim_win_set_cursor(win, { 3, 0 })
		end

		-- Plugin commands with multi-select
		function M.generate_getters()
			local class_info = find_class_info()
			if #class_info.fields == 0 then
				print("No fields found in class")
				return
			end
			select_fields(class_info.fields, "Select fields for getters:", function(selected_fields)
				if #selected_fields == 0 then
					print("No fields selected for getters")
					return
				end

				local methods = {}
				for _, field in ipairs(selected_fields) do
					local getter = generate_getter(field)
					for _, line in ipairs(getter) do
						table.insert(methods, line)
					end
				end

				insert_methods(methods)
				print("Generated getters for " .. #selected_fields .. " fields")
			end)
		end

		function M.generate_setters()
			local class_info = find_class_info()
			if #class_info.fields == 0 then
				print("No fields found in class")
				return
			end
			select_fields(class_info.fields, "Select fields for setters:", function(selected_fields)
				if #selected_fields == 0 then
					print("No fields selected for setters")
					return
				end

				local methods = {}
				for _, field in ipairs(selected_fields) do
					local setter = generate_setter(field)
					for _, line in ipairs(setter) do
						table.insert(methods, line)
					end
				end

				insert_methods(methods)
				print("Generated setters for " .. #selected_fields .. " fields")
			end)
		end

		function M.generate_constructor()
			local class_info = find_class_info()
			if #class_info.fields == 0 then
				print("No fields found in class")
				return
			end
			select_fields(class_info.fields, "Select fields for constructor:", function(selected_fields)
				if not class_info.class_name then
					print("No class found")
					return
				end

				local constructor = generate_constructor(class_info.class_name, selected_fields)
				insert_methods(constructor)
				print("Generated constructor with " .. #selected_fields .. " fields")
			end)
		end

		function M.generate_all()
			local class_info = find_class_info()
			if #class_info.fields == 0 then
				print("No fields found in class")
				return
			end
			select_fields(class_info.fields, "Select fields for all accessors:", function(selected_fields)
				if #selected_fields == 0 then
					print("No fields selected")
					return
				end

				local methods = {}

				-- Generate constructor
				local constructor = generate_constructor(class_info.class_name, selected_fields)
				for _, line in ipairs(constructor) do
					table.insert(methods, line)
				end

				-- Generate getters and setters
				for _, field in ipairs(selected_fields) do
					local getter = generate_getter(field)
					local setter = generate_setter(field)

					for _, line in ipairs(getter) do
						table.insert(methods, line)
					end

					for _, line in ipairs(setter) do
						table.insert(methods, line)
					end
				end

				insert_methods(methods)
				print("Generated all accessors for " .. #selected_fields .. " fields")
			end)
		end

		function M.generate_tostring()
			local class_info = find_class_info()
			if #class_info.fields == 0 then
				print("No fields found in class")
				return
			end
			select_fields(class_info.fields, "Select fields for toString:", function(selected_fields)
				if not class_info.class_name then
					print("No class found")
					return
				end

				local tostring = generate_tostring(class_info.class_name, selected_fields)
				insert_methods(tostring)
				print("Generated toString with " .. #selected_fields .. " fields")
			end)
		end

		function M.generate_equals()
			local class_info = find_class_info()
			if #class_info.fields == 0 then
				print("No fields found in class")
				return
			end
			select_fields(class_info.fields, "Select fields for equals/hashCode:", function(selected_fields)
				if not class_info.class_name then
					print("No class found")
					return
				end

				local equals = generate_equals_hashcode(class_info.class_name, selected_fields)
				insert_methods(equals)
				print("Generated equals/hashCode with " .. #selected_fields .. " fields")
			end)
		end

		function M.generate_builder()
			local class_info = find_class_info()
			if #class_info.fields == 0 then
				print("No fields found in class")
				return
			end
			select_fields(class_info.fields, "Select fields for builder:", function(selected_fields)
				if not class_info.class_name then
					print("No class found")
					return
				end

				local builder = generate_builder(class_info.class_name, selected_fields)
				insert_methods(builder)
				print("Generated builder with " .. #selected_fields .. " fields")
			end)
		end

		-- Create an autocmd to set up commands only for Java files
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "java",
			callback = function()
				-- Create buffer-local commands only when a Java file is opened
				vim.api.nvim_buf_create_user_command(0, "JavaGenerateGetters", M.generate_getters, {})
				vim.api.nvim_buf_create_user_command(0, "JavaGenerateSetters", M.generate_setters, {})
				vim.api.nvim_buf_create_user_command(0, "JavaGenerateConstructor", M.generate_constructor, {})
				vim.api.nvim_buf_create_user_command(0, "JavaGenerateAll", M.generate_all, {})
				vim.api.nvim_buf_create_user_command(0, "JavaGenerateToString", M.generate_tostring, {})
				vim.api.nvim_buf_create_user_command(0, "JavaGenerateEquals", M.generate_equals, {})
				vim.api.nvim_buf_create_user_command(0, "JavaGenerateBuilder", M.generate_builder, {})
			end,
		})
	end,
}
