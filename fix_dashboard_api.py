import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove initialProjects array completely
content = re.sub(r'const initialProjects = \[\s*\{.*?\}\s*\];\s*', '', content, flags=re.DOTALL)

# 2. Update states
state_replacements = """  const [isLoggingOut, setIsLoggingOut] = useState(false);
  const [projects, setProjects] = useState<any[]>([]);
  const [isLoadingProjects, setIsLoadingProjects] = useState(true);
  const [isCreatingProject, setIsCreatingProject] = useState(false);"""
content = re.sub(r'  const \[isLoggingOut, setIsLoggingOut\] = useState\(false\);\n  const \[projects, setProjects\] = useState\(initialProjects\);', state_replacements, content)

# 3. Add fetchProjects logic right before `handleCreateProject`
fetch_logic = """  const fetchProjects = async () => {
    try {
      const res = await fetch("/api/projects");
      if (res.ok) {
        const data = await res.json();
        setProjects(data);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setIsLoadingProjects(false);
    }
  };

  useEffect(() => {
    if (session) {
      fetchProjects();
    }
  }, [session]);

  const handleCreateProject"""
content = content.replace('  const handleCreateProject', fetch_logic)

# 4. Replace handleCreateProject with API call
old_handle_create = """  const handleCreateProject = () => {
    if (!newProjectName.trim()) return;
    
    const newProject = {
      id: Date.now(),
      name: newProjectName.toLowerCase().replace(/\s+/g, '-'),
      framework: "Unknown",
      status: "active",
      url: "bekleniyor...",
      traffic: "0",
      dataUsage: "0 B",
      lastDeployed: "Just now"
    };

    setProjects([newProject, ...projects]);
    setIsModalOpen(false);
    setNewProjectName("");
  };"""

new_handle_create = """  const handleCreateProject = async () => {
    if (!newProjectName.trim()) return;
    
    setIsCreatingProject(true);
    try {
      const res = await fetch("/api/projects", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: newProjectName.toLowerCase().replace(/\s+/g, '-'),
          plan: selectedTier
        })
      });

      if (res.ok) {
        const newProject = await res.json();
        setProjects([newProject, ...projects]);
        setIsModalOpen(false);
        setNewProjectName("");
      }
    } catch (e) {
      console.error("Error creating project:", e);
    } finally {
      setIsCreatingProject(false);
    }
  };"""
content = content.replace(old_handle_create, new_handle_create)

# 5. Add loading spinner to button
old_button = """                <button 
                  onClick={handleCreateProject}
                  disabled={!newProjectName.trim()}
                  className="px-6 py-2 bg-[#FF5708] hover:bg-[#FF5708] text-white text-sm font-semibold rounded-lg transition-colors disabled:opacity-50 shadow-[0_0_15px_rgba(255,87,8,0.2)]"
                >
                  {t("Projeyi Oluştur")}
                </button>"""

new_button = """                <button 
                  onClick={handleCreateProject}
                  disabled={!newProjectName.trim() || isCreatingProject}
                  className="px-6 py-2 bg-[#FF5708] hover:bg-[#FF5708] text-white text-sm font-semibold rounded-lg transition-colors disabled:opacity-50 shadow-[0_0_15px_rgba(255,87,8,0.2)] flex items-center justify-center min-w-[140px]"
                >
                  {isCreatingProject ? <Loader2 className="w-4 h-4 animate-spin" /> : t("Projeyi Oluştur")}
                </button>"""
content = content.replace(old_button, new_button)

# 6. Make sure the initial render shows loading state for projects
old_projects_grid = """          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {projects.map((project) => ("""

new_projects_grid = """          {isLoadingProjects ? (
            <div className="flex items-center justify-center py-20">
              <Loader2 className="w-8 h-8 animate-spin text-[#FF5708]" />
            </div>
          ) : projects.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 bg-[#050505] rounded-xl border border-zinc-800/50 border-dashed">
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
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {projects.map((project) => ("""

# wait, I need to close the `) : (` block properly at the end of the grid. Let's do it via python string matching carefully.
# Actually I'll use a regex to wrap the grid.
grid_match = re.search(r'(<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">.*?</div>\n          </div>)', content, re.DOTALL)
if grid_match:
    grid_content = grid_match.group(1)
    new_grid_content = """          {isLoadingProjects ? (
            <div className="flex items-center justify-center py-20">
              <Loader2 className="w-8 h-8 animate-spin text-[#FF5708]" />
            </div>
          ) : projects.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 bg-[#050505] rounded-xl border border-zinc-800/50 border-dashed">
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
  """ + grid_content.replace('</div>\n          </div>', '</div>\n          </div>\n          )}').replace('          <div className="grid grid-cols-1', '        <div className="grid grid-cols-1')
    content = content.replace(grid_content, new_grid_content)

# We also need to fix mapping variables in the grid because I changed project keys (e.g. project._id instead of project.id)
# Let's just fix it globally.
content = content.replace('key={project.id}', 'key={project._id || project.id}')
content = content.replace('project.lastDeployed', 'new Date(project.createdAt).toLocaleDateString()')
content = content.replace('project.framework', 'project.plan.toUpperCase()')

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Dashboard refactored.")
