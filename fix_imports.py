import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the lucide-react import line
old_import = re.search(r'import \{[^}]+\} from "lucide-react";', content).group(0)

# The new ones we need:
# Plus, Search, FolderKanban, Activity, Server, MoreVertical, LayoutDashboard, Globe, Shield, Terminal, ArrowUpRight, LogOut, Loader2, User, Key, Check, X, Settings, Lock
new_import = 'import { Plus, Search, FolderKanban, Activity, Server, MoreVertical, LayoutDashboard, Globe, Shield, Terminal, ArrowUpRight, LogOut, Loader2, User, Key, Check, X, Settings, Lock } from "lucide-react";'

content = content.replace(old_import, new_import)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed imports")
