page_file = "apps/web/app/page.tsx"
with open(page_file, "r") as f:
    page_content = f.read()

old_hero_btn = """            <button 
              onClick={() => router.push("/login?mode=signup")}
              className="w-full sm:w-auto group inline-flex items-center justify-center rounded-lg bg-[#FF5708] font-medium text-white transition-all duration-300 hover:bg-[#ff6c26] hover:shadow-[0_0_30px_rgba(255,87,8,0.4)] active:scale-95 h-12 px-8 text-base"
            >
              Keşfetmeye Başla
              <ArrowRight className="w-4 h-4 ml-2 group-hover:translate-x-1 transition-transform" />
            </button>"""

new_hero_btn = """            <button 
              onClick={() => router.push(session ? "/dashboard" : "/login?mode=signup")}
              className="w-full sm:w-auto group inline-flex items-center justify-center rounded-lg bg-[#FF5708] font-medium text-white transition-all duration-300 hover:bg-[#ff6c26] hover:shadow-[0_0_30px_rgba(255,87,8,0.4)] active:scale-95 h-12 px-8 text-base"
            >
              {session ? "Dashboard'a Git" : "Keşfetmeye Başla"}
              <ArrowRight className="w-4 h-4 ml-2 group-hover:translate-x-1 transition-transform" />
            </button>"""

if old_hero_btn in page_content:
    page_content = page_content.replace(old_hero_btn, new_hero_btn)
    with open(page_file, "w") as f:
        f.write(page_content)
    print("Updated hero button.")
else:
    print("Hero button not found.")
