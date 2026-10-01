import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update Sidebar Profile Footer
old_sidebar_user = """        {/* User Profile Footer */}
        <div className="p-4 border-t border-zinc-800/60">
          <div className="flex items-center gap-3 px-2 py-2">
            <div className="w-9 h-9 rounded-full bg-zinc-800 flex items-center justify-center border border-zinc-700 text-sm font-medium">
              {session.user.name?.charAt(0).toUpperCase() || "U"}
            </div>
            <div className="flex-1 overflow-hidden">
              <p className="text-sm font-medium truncate">{session.user.name || "Kullanıcı"}</p>
              <p className="text-xs text-zinc-500 truncate">{session.user.email}</p>
            </div>
          </div>"""

new_sidebar_user = """        {/* User Profile Footer */}
        <div className="p-4 border-t border-zinc-800/60">
          <div className="flex items-center gap-3 px-2 py-2">
            <div className={`w-9 h-9 rounded-full ${avatars[displayAvatar]} flex items-center justify-center border border-zinc-700/60 text-sm font-medium shadow-sm transition-all duration-300 overflow-hidden`}>
              <User className="w-4 h-4 text-white/80" />
            </div>
            <div className="flex-1 overflow-hidden">
              <p className="text-sm font-medium truncate">{displayName || session.user.name || "Kullanıcı"}</p>
              <p className="text-xs text-zinc-500 truncate">{session.user.email}</p>
            </div>
          </div>"""

content = content.replace(old_sidebar_user, new_sidebar_user)

# 2. Update Top Navbar breadcrumb
old_navbar_user = '<span className="hover:text-zinc-200 cursor-pointer transition-colors">{session.user.name || "Hesap"}</span>'
new_navbar_user = '<span className="hover:text-zinc-200 cursor-pointer transition-colors">{displayName || session.user.name || "Hesap"}</span>'
content = content.replace(old_navbar_user, new_navbar_user)

# 3. Update Greeting header
old_greeting = '<h1 className="text-2xl font-semibold tracking-tight">Hoş Geldin, {session.user.name?.split(" ")[0] || "Kullanıcı"}</h1>'
new_greeting = '<h1 className="text-2xl font-semibold tracking-tight">Hoş Geldin, {(displayName || session.user.name)?.split(" ")[0] || "Kullanıcı"}</h1>'
content = content.replace(old_greeting, new_greeting)

# 4. Replace remaining alerts in project creation
content = content.replace(
    'alert("Proje oluşturulurken hata oluştu. Lütfen konsolu kontrol edin.");',
    'showToast("Proje oluşturulurken hata oluştu", "error");'
)
content = content.replace(
    'alert("Bağlantı hatası oluştu.");',
    'showToast("Bağlantı hatası oluştu", "error");'
)

# 5. Connect Email update input and button
old_email_section = """                          <div>
                            <label className="block text-sm font-medium text-zinc-400 mb-1.5">{t("Yeni E-posta Adresi")}</label>
                            <div className="relative">
                              <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                              <input type="email" placeholder="yeni@ornek.com" className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />
                            </div>
                          </div>
                          <div className="pt-2 flex justify-end">
                            <button className="px-6 py-2 bg-[#FF5708] hover:bg-[#ff6c26] text-white text-sm font-semibold rounded-lg transition-colors">
                              {t("E-postayı Güncelle")}
                            </button>
                          </div>"""

new_email_section = """                          <div>
                            <label className="block text-sm font-medium text-zinc-400 mb-1.5">{t("Yeni E-posta Adresi")}</label>
                            <div className="relative">
                              <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                              <input 
                                type="email" 
                                value={newEmail} 
                                onChange={(e) => setNewEmail(e.target.value)} 
                                placeholder="yeni@ornek.com" 
                                className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" 
                              />
                            </div>
                          </div>
                          <div className="pt-2 flex justify-end">
                            <button 
                              onClick={handleUpdateEmail}
                              disabled={isSavingEmail}
                              className="px-6 py-2 bg-[#FF5708] hover:bg-[#ff6c26] text-white text-sm font-semibold rounded-lg transition-colors flex items-center justify-center min-w-[150px]"
                            >
                              {isSavingEmail ? <Loader2 className="w-4 h-4 animate-spin" /> : t("E-postayı Güncelle")}
                            </button>
                          </div>"""

content = content.replace(old_email_section, new_email_section)

# 6. Add custom Toast UI at bottom before the final closing div
toast_jsx = """
      {/* Toast Notification (Bottom Right) */}
      <AnimatePresence>
        {toast.visible && (
          <motion.div
            initial={{ opacity: 0, y: 25, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 20, scale: 0.95 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className={`fixed bottom-6 right-6 z-[100] flex items-center gap-3 px-4 py-3 rounded-xl border shadow-[0_12px_35px_rgba(0,0,0,0.6)] backdrop-blur-md ${
              toast.type === 'error'
                ? 'bg-[#181214] border-red-500/30 text-zinc-100'
                : 'bg-[#121814] border-emerald-500/30 text-zinc-100'
            }`}
          >
            <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${
              toast.type === 'error'
                ? 'bg-red-500/10 text-red-400 border border-red-500/20'
                : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 shadow-[0_0_12px_rgba(16,185,129,0.2)]'
            }`}>
              {toast.type === 'error' ? <X className="w-4 h-4" /> : <Check className="w-4 h-4" />}
            </div>
            <div className="text-sm font-medium pr-1">
              {toast.message}
            </div>
            <button
              onClick={() => setToast(prev => ({ ...prev, visible: false }))}
              className="text-zinc-500 hover:text-zinc-300 p-1 rounded-md transition-colors ml-1"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </motion.div>
        )}
      </AnimatePresence>
"""

# Insert right before the last closing </div> of the page component
content = re.sub(r'(\s*</div>\s*\);\s*}\s*)$', toast_jsx + r'\1', content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Dashboard UI and Toast successfully updated")
