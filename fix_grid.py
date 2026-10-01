import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace from '<div className="grid grid-cols-1 lg:grid-cols-2 gap-4">' to the matching closing div
pattern = r'<div className="grid grid-cols-1 lg:grid-cols-2 gap-4">\s*\{projects\.map\(\(project\).*?</div>\s*</div>\s*</div>\s*\)\)\}\s*</div>'

match = re.search(pattern, content, re.DOTALL)
if match:
    old_grid = match.group(0)
    new_grid = """{isLoadingProjects ? (
                <div className="flex justify-center items-center py-12">
                  <Loader2 className="w-6 h-6 animate-spin text-[#FF5708]" />
                </div>
              ) : projects.length === 0 ? (
                <div className="col-span-full flex flex-col items-center justify-center py-16 bg-[#0a0a0a] rounded-xl border border-zinc-800/50 border-dashed">
                  <div className="w-12 h-12 rounded-full bg-zinc-900 flex items-center justify-center mb-4">
                    <FolderKanban className="w-6 h-6 text-zinc-500" />
                  </div>
                  <h3 className="text-zinc-300 font-medium mb-1">Henüz proje yok</h3>
                  <p className="text-zinc-500 text-sm mb-4">İlk projenizi oluşturarak başlayın.</p>
                  <button 
                    onClick={() => setIsModalOpen(true)}
                    className="text-[#FF5708] hover:text-[#ff6c26] text-sm font-medium flex items-center transition-colors"
                  >
                    <Plus className="w-4 h-4 mr-1" />
                    {t("Yeni Proje Oluştur")}
                  </button>
                </div>
              ) : (
                """ + old_grid + "\n              )}"
    
    content = content.replace(old_grid, new_grid)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Fixed grid!")
else:
    print("Could not find grid pattern.")
