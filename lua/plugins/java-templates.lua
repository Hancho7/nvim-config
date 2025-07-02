return {
	"nvim-lua/plenary.nvim", -- Required for the template system
	config = function()
		-- Function to get package name from file path
		local function get_package_name(filepath)
			local path_parts = vim.split(filepath, "/", { plain = true })
			local java_index = nil

			-- Find the 'java' directory in the path
			for i, part in ipairs(path_parts) do
				if part == "java" then
					java_index = i
					break
				end
			end

			if not java_index then
				return ""
			end

			-- Get package parts (everything after java/ except the filename)
			local package_parts = {}
			for i = java_index + 1, #path_parts - 1 do
				table.insert(package_parts, path_parts[i])
			end

			if #package_parts == 0 then
				return ""
			end

			return "package " .. table.concat(package_parts, ".") .. ";"
		end

		-- Function to get class name from filename
		local function get_class_name(filepath)
			local filename = vim.fn.fnamemodify(filepath, ":t")
			return vim.fn.fnamemodify(filename, ":r")
		end

		-- Template functions
		local templates = {
			class = function(package_name, class_name)
				return string.format(
					[[%s

public class %s {

    public %s() {

    }

}]],
					package_name,
					class_name,
					class_name
				)
			end,

			interface = function(package_name, class_name)
				return string.format(
					[[%s

public interface %s {

}]],
					package_name,
					class_name
				)
			end,

			record = function(package_name, class_name)
				return string.format(
					[[%s

public record %s() {

}]],
					package_name,
					class_name
				)
			end,

			enum = function(package_name, class_name)
				return string.format(
					[[%s

public enum %s {

}]],
					package_name,
					class_name
				)
			end,

			abstract_class = function(package_name, class_name)
				return string.format(
					[[%s

public abstract class %s {

}]],
					package_name,
					class_name
				)
			end,

			spring_controller = function(package_name, class_name)
				return string.format(
					[[%s

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class %s {

    @GetMapping
    public String hello() {
        return "Hello World!";
    }

}]],
					package_name,
					class_name
				)
			end,

			spring_service = function(package_name, class_name)
				return string.format(
					[[%s

import org.springframework.stereotype.Service;

@Service
public class %s {

}]],
					package_name,
					class_name
				)
			end,

			spring_entity = function(package_name, class_name)
				return string.format(
					[[%s

import jakarta.persistence.*;

@Entity
@Table(name = "%s")
public class %s {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Constructors
    public %s() {}

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

}]],
					package_name,
					string.lower(class_name),
					class_name,
					class_name
				)
			end,
		}

		-- Function to show template selection
		local function select_java_template()
			local current_file = vim.fn.expand("%:p")
			local package_name = get_package_name(current_file)
			local class_name = get_class_name(current_file)

			-- If no package name found, ask user
			if package_name == "" then
				package_name = vim.fn.input("Package name (leave empty for no package): ")
				if package_name ~= "" then
					package_name = "package " .. package_name .. ";"
				end
			end

			local template_options = {
				"class",
				"interface",
				"record",
				"enum",
				"abstract_class",
				"spring_controller",
				"spring_service",
				"spring_entity",
			}

			vim.ui.select(template_options, {
				prompt = "Select Java template:",
				format_item = function(item)
					return item:gsub("_", " "):gsub("^%l", string.upper)
				end,
			}, function(choice)
				if choice then
					local content = templates[choice](package_name, class_name)

					-- Clear the buffer and insert template
					vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n"))

					-- Position cursor after the opening brace or in a logical place
					if choice == "record" then
						vim.api.nvim_win_set_cursor(0, { 4, 15 }) -- Inside record parentheses
					else
						vim.api.nvim_win_set_cursor(0, { 5, 4 }) -- Inside the class/interface body
					end
				end
			end)
		end

		-- Auto-command to trigger template selection for new Java files
		vim.api.nvim_create_autocmd("BufNewFile", {
			pattern = "*.java",
			callback = function()
				-- Small delay to ensure buffer is fully loaded
				vim.defer_fn(function()
					-- Only show template selection for empty files
					if vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "" then
						select_java_template()
					end
				end, 100)
			end,
		})

		-- Command to manually trigger template selection
		vim.api.nvim_create_user_command("JavaTemplate", select_java_template, {
			desc = "Insert Java template for current file",
		})

		-- Keymap for quick access
		vim.keymap.set("n", "<leader>jt", select_java_template, { desc = "[J]ava [T]emplate" })
	end,
}
