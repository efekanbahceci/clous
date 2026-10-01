import re

auth_file = "apps/web/lib/auth.ts"
with open(auth_file, "r") as f:
    auth_content = f.read()

# Replace the session block with a highly explicit 2-day limit
new_session_block = """  session: {
    expiresIn: 60 * 60 * 24 * 2, // Kesin 2 gün (saniye cinsinden)
    updateAge: 60 * 60 * 24 * 2, // Oturumun otomatik uzamasını engelle, tam 2 günde bitsin
  },"""

auth_content = re.sub(r'  session: \{[\s\S]*?\},', new_session_block, auth_content)

with open(auth_file, "w") as f:
    f.write(auth_content)

print("Updated auth.ts with strict 2-day limit")
