import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the lucide-react import line entirely with all detected icons
old_import = re.search(r'import \{[^}]+\} from "lucide-react";', content).group(0)

new_import = 'import { Activity, ArrowUpRight, Bell, Check, CheckCircle, ChevronRight, Copy, Database, FolderKanban, Globe, Key, LayoutDashboard, Loader2, Lock, LogOut, MoreVertical, Plus, Search, Server, Settings, Shield, Terminal, User, X } from "lucide-react";'

content = content.replace(old_import, new_import)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed all lucide imports")
