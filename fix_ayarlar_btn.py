import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the specific <a> tag for "Ayarlar" with a <button onClick={() => setIsSettingsOpen(true)}>
old_button_pattern = r'<a href="#" className="flex items-center gap-3 px-3 py-2\.5 text-zinc-400 hover:text-zinc-100 hover:bg-zinc-900/50 rounded-lg transition-colors">\s*<Settings className="w-4 h-4" />\s*<span className="text-sm font-medium">\{t\("Ayarlar"\)\}</span>\s*</a>'

new_button = """<button onClick={() => setIsSettingsOpen(true)} className="w-full flex items-center gap-3 px-3 py-2.5 text-zinc-400 hover:text-zinc-100 hover:bg-zinc-900/50 rounded-lg transition-colors text-left">
            <Settings className="w-4 h-4" />
            <span className="text-sm font-medium">{t("Ayarlar")}</span>
          </button>"""

content = re.sub(old_button_pattern, new_button, content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed Ayarlar button")
