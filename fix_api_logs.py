import re

route_file = "apps/web/app/api/projects/route.ts"
with open(route_file, "r") as f:
    content = f.read()

# Add a debug log for session
content = content.replace(
    'const session = await auth.api.getSession({\n      headers: headers()\n    });\n\n    if (!session?.user) {',
    'const session = await auth.api.getSession({\n      headers: headers()\n    });\n    console.log("POST /api/projects - session:", session ? session.user.id : "No Session");\n\n    if (!session?.user) {'
)

# wait, I'll just write a new file completely to be safe.
