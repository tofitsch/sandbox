" OSC 52 clipboard provider: yanks reach the terminal's system clipboard over
" raw escape codes, so it works the same natively and inside this container
" or over ssh (kitty allows OSC 52 writes by default; reads are blocked by
" kitty by default, so paste falls back to the unnamed register).
lua << EOF
local function osc52_copy(reg)
  return function(lines, _)
    local data = table.concat(lines, "\n")
    local encoded = vim.fn.system("base64 | tr -d '\n'", data)
    local seq = "\027]52;" .. reg .. ";" .. encoded .. "\007"
    if vim.env.TMUX then
      seq = "\027Ptmux;\027" .. seq .. "\027\\"
    end
    io.stdout:write(seq)
  end
end

local function osc52_paste(reg)
  return function()
    return { vim.fn.split(vim.fn.getreg(reg), "\n"), vim.fn.getregtype(reg) }
  end
end

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = osc52_copy("c"),
    ["*"] = osc52_copy("c"),
  },
  paste = {
    ["+"] = osc52_paste("+"),
    ["*"] = osc52_paste("*"),
  },
}
EOF
