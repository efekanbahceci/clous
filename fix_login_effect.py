with open("apps/web/app/login/page.tsx", "r") as f:
    content = f.read()

# Add useEffect for searchParams changes
effect_code = """  const [isSignUp, setIsSignUp] = useState(searchParams.get("mode") === "signup");
  
  import_react = False
  # Wait, useEffect is already imported from "react"? Let's check imports.
"""

import re
# check if useEffect is imported
if "useEffect" not in content:
    content = content.replace('import { useState, Suspense } from "react";', 'import { useState, Suspense, useEffect } from "react";')

effect_code = """
  useEffect(() => {
    if (searchParams.get("mode") === "signup") {
      setIsSignUp(true);
    } else {
      setIsSignUp(false);
    }
  }, [searchParams]);
"""

# inject effect after the states
content = content.replace('const [githubLoading, setGithubLoading] = useState(false);', 'const [githubLoading, setGithubLoading] = useState(false);\n' + effect_code)

with open("apps/web/app/login/page.tsx", "w") as f:
    f.write(content)
