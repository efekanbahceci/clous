with open("apps/web/app/page.tsx", "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    # Line 144 is the "Kayıt Ol" button
    if "Kayıt Ol" in ''.join(lines[i:i+5]) and 'router.push("/login")' in line:
        lines[i] = line.replace('router.push("/login")', 'router.push("/login?mode=signup")')
    # Line 200 is "Keşfetmeye Başla"
    if "Keşfetmeye Başla" in ''.join(lines[i:i+5]) and 'router.push("/login")' in line:
        lines[i] = line.replace('router.push("/login")', 'router.push("/login?mode=signup")')

with open("apps/web/app/page.tsx", "w") as f:
    f.writelines(lines)
print("Updated page.tsx routing.")
