import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

pattern = r'  const handleCreateProject = \(\) => \{[\s\S]*?setSelectedTier\("free"\);\n  \};'
match = re.search(pattern, content)

new_handle = """  const handleCreateProject = async () => {
    if (!newProjectName.trim()) return;
    
    setIsCreatingProject(true);
    try {
      const res = await fetch("/api/projects", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: newProjectName.toLowerCase().replace(/\\s+/g, '-'),
          plan: selectedTier
        })
      });

      if (res.ok) {
        const newProject = await res.json();
        setProjects([newProject, ...projects]);
        setIsModalOpen(false);
        setNewProjectName("");
        setSelectedTier("free");
      } else {
        console.error("API Error:", await res.text());
        alert("Proje oluşturulurken hata oluştu. Lütfen konsolu kontrol edin.");
      }
    } catch (e) {
      console.error("Error creating project:", e);
      alert("Bağlantı hatası oluştu.");
    } finally {
      setIsCreatingProject(false);
    }
  };"""

if match:
    content = content.replace(match.group(0), new_handle)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Fixed handleCreateProject!")
else:
    print("No match found.")
