import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
        
    # fix missing closing paren for NextResponse.json
    content = re.sub(r'NextResponse\.json\((.*?)\s*$', r'NextResponse.json(\1});', content, flags=re.MULTILINE)
    content = re.sub(r'NextResponse\.json\(\{\s*(.*?)\s*\n$', r'NextResponse.json({ \1 });\n', content, flags=re.MULTILINE)
    
    # fix the specific missing `});` in JSON responses at the end of block
    content = re.sub(r'return NextResponse\.json\(\{\s*(.*?)\s*$', r'return NextResponse.json({ \1 });\n', content, flags=re.MULTILINE)
    
    with open(filepath, 'w') as f:
        f.write(content)

# Let's write a very specific regex for the files
def specific_fix(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # In env/route.ts
    content = content.replace("customEnvs: customEnvs || []\n     \n  } catch", "customEnvs: customEnvs || []\n    });\n  } catch")
    content = content.replace("return NextResponse.json({ success: true, item: envItem  \n  } catch", "return NextResponse.json({ success: true, item: envItem });\n  } catch")
    
    # In link/route.ts
    content = content.replace("userId = anyUser.id || anyUser._id?.toString();\n        }\n      }\n    }\n  }\n\n  if (!userId) {", "userId = anyUser.id || anyUser._id?.toString();\n        }\n      }\n    }\n\n  if (!userId) {")
    content = content.replace("const dbSession = await db.collection('session').findOne({ token  \n      if", "const dbSession = await db.collection('session').findOne({ token });\n      if")
    
    # In traffic/route.ts
    content = content.replace('await db.collection("project_traffic").deleteMany({ projectId: id  \n\n      const now', 'await db.collection("project_traffic").deleteMany({ projectId: id });\n\n      const now')

    # Fix generic json return issues
    content = content.replace("  \n    }", " });\n    }")
    content = content.replace("  \n  } catch", " });\n  } catch")
    
    with open(filepath, 'w') as f:
        f.write(content)

base = 'apps/web/app/api'
files = [
    f'{base}/projects/[id]/env/route.ts',
    f'{base}/projects/[id]/link/route.ts',
    f'{base}/projects/[id]/route.ts',
    f'{base}/projects/[id]/traffic/route.ts',
    f'{base}/user/accounts/route.ts'
]

for f in files:
    specific_fix(f)
