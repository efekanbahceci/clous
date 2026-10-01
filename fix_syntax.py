import re

files = [
    "apps/web/app/page.tsx",
    "apps/web/app/dashboard/page.tsx",
    "apps/web/app/login/page.tsx",
]

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix '"{t("...")}"' -> 't("...")'
    content = re.sub(r'"{t\("([^"]+)"\)}"', r't("\1")', content)
    # Fix `"{t("...")}"` -> `t("...")` (if any with backticks inside or outside)
    
    # Fix double >{t(">...<")}<
    content = re.sub(r'>{t\(">[^<]+<"\)}<', lambda m: m.group(0).replace('>"', '"').replace('"<', '"').replace('>{t(">', '>{t("').replace('<")}<', '")}<'), content)
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Syntax fix done.")
