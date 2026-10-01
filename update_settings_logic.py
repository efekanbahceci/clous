import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add states for settings logic
state_insert_pattern = r"const \[settingsTab, setSettingsTab\] = useState\('profil'\);"
state_insert_code = """const [settingsTab, setSettingsTab] = useState('profil');
  const [linkedAccounts, setLinkedAccounts] = useState<any[]>([]);
  const [userName, setUserName] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [isSavingSecurity, setIsSavingSecurity] = useState(false);

  useEffect(() => {
    if (session?.user?.name && !userName) {
      setUserName(session.user.name);
    }
  }, [session]);

  useEffect(() => {
    if (isSettingsOpen) {
      fetch("/api/user/accounts").then(r => r.json()).then(data => {
        if(Array.isArray(data)) setLinkedAccounts(data);
      }).catch(console.error);
    }
  }, [isSettingsOpen]);

  const handleSaveProfile = async () => {
    setIsSavingProfile(true);
    try {
      const res = await fetch("/api/user/profile", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: userName, image: avatars[selectedAvatar] })
      });
      if(res.ok) alert("Profil güncellendi! (Yeniden giriş yaptığınızda tam yansıyabilir)");
      else alert("Profil güncellenirken hata oluştu.");
    } catch(e) {
      alert("Bağlantı hatası");
    }
    setIsSavingProfile(false);
  };

  const handleSavePassword = async () => {
    if(!currentPassword || !newPassword) {
      alert("Lütfen tüm alanları doldurun.");
      return;
    }
    setIsSavingSecurity(true);
    try {
      const res = await fetch("/api/user/password", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ currentPassword, newPassword })
      });
      if(res.ok) {
        alert("Şifreniz başarıyla güncellendi!");
        setCurrentPassword("");
        setNewPassword("");
      } else alert("Şifre güncellenirken hata oluştu.");
    } catch(e) {
      alert("Bağlantı hatası");
    }
    setIsSavingSecurity(false);
  };
"""
content = re.sub(state_insert_pattern, state_insert_code, content)

# Fix Profil Tab inputs and save button
content = content.replace(
    '<input type="text" defaultValue={session?.user?.name || ""} className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />',
    '<input type="text" value={userName} onChange={(e) => setUserName(e.target.value)} className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />'
)

content = content.replace(
    '<button className="px-6 py-2 bg-[#FF5708] hover:bg-[#ff6c26] text-white text-sm font-semibold rounded-lg transition-colors">\n                          {t("Değişiklikleri Kaydet")}\n                        </button>',
    '<button onClick={handleSaveProfile} disabled={isSavingProfile} className="px-6 py-2 bg-[#FF5708] hover:bg-[#ff6c26] text-white text-sm font-semibold rounded-lg transition-colors flex items-center justify-center min-w-[150px]">\n                          {isSavingProfile ? <Loader2 className="w-4 h-4 animate-spin" /> : t("Değişiklikleri Kaydet")}\n                        </button>'
)

# Fix Linked Accounts logic
old_linked = """<div className="space-y-3">
                          <div className="flex items-center justify-between p-4 rounded-xl bg-[#111111] border border-zinc-800/80">
                            <div className="flex items-center gap-3">
                              <Github className="w-5 h-5 text-white" />
                              <div>
                                <h4 className="text-sm font-medium text-white">{t("Github Hesabı")}</h4>
                                <p className="text-xs text-zinc-500">{t("Bağlı Değil")}</p>
                              </div>
                            </div>
                            <button className="px-3 py-1.5 text-xs font-medium bg-zinc-800 hover:bg-zinc-700 text-white rounded-md transition-colors">Bağla</button>
                          </div>
                          <div className="flex items-center justify-between p-4 rounded-xl bg-[#111111] border border-zinc-800/80">
                            <div className="flex items-center gap-3">
                              <Mail className="w-5 h-5 text-red-400" />
                              <div>
                                <h4 className="text-sm font-medium text-white">{t("Google Hesabı")}</h4>
                                <p className="text-xs text-zinc-500">{t("Aktif")}</p>
                              </div>
                            </div>
                            <button className="px-3 py-1.5 text-xs font-medium bg-zinc-900 text-zinc-500 border border-zinc-800 rounded-md cursor-not-allowed">Bağlı</button>
                          </div>
                        </div>"""

new_linked = """<div className="space-y-3">
                          <div className="flex items-center justify-between p-4 rounded-xl bg-[#111111] border border-zinc-800/80">
                            <div className="flex items-center gap-3">
                              <Github className="w-5 h-5 text-white" />
                              <div>
                                <h4 className="text-sm font-medium text-white">{t("Github Hesabı")}</h4>
                                <p className="text-xs text-zinc-500">{linkedAccounts.some(a => a.providerId === 'github') ? t("Aktif") : t("Bağlı Değil")}</p>
                              </div>
                            </div>
                            {linkedAccounts.some(a => a.providerId === 'github') ? (
                              <button className="px-3 py-1.5 text-xs font-medium bg-zinc-900 text-zinc-500 border border-zinc-800 rounded-md cursor-not-allowed">Bağlı</button>
                            ) : (
                              <button className="px-3 py-1.5 text-xs font-medium bg-zinc-800 hover:bg-zinc-700 text-white rounded-md transition-colors">Bağla</button>
                            )}
                          </div>
                          <div className="flex items-center justify-between p-4 rounded-xl bg-[#111111] border border-zinc-800/80">
                            <div className="flex items-center gap-3">
                              <Mail className="w-5 h-5 text-red-400" />
                              <div>
                                <h4 className="text-sm font-medium text-white">{t("Google Hesabı")}</h4>
                                <p className="text-xs text-zinc-500">{linkedAccounts.some(a => a.providerId === 'google') ? t("Aktif") : t("Bağlı Değil")}</p>
                              </div>
                            </div>
                            {linkedAccounts.some(a => a.providerId === 'google') ? (
                              <button className="px-3 py-1.5 text-xs font-medium bg-zinc-900 text-zinc-500 border border-zinc-800 rounded-md cursor-not-allowed">Bağlı</button>
                            ) : (
                              <button className="px-3 py-1.5 text-xs font-medium bg-zinc-800 hover:bg-zinc-700 text-white rounded-md transition-colors">Bağla</button>
                            )}
                          </div>
                        </div>"""
content = content.replace(old_linked, new_linked)

# Fix Password fields and save button
content = content.replace(
    '<input type="password" placeholder="••••••••" className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />',
    '<input type="password" value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} placeholder="••••••••" className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />',
    1 # Only first match (Eski Sifre)
)

content = content.replace(
    '<input type="password" placeholder="••••••••" className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />',
    '<input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} placeholder="••••••••" className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />',
    1 # Second match (Yeni Sifre)
)

content = content.replace(
    '<button className="px-6 py-2 bg-[#111111] border border-zinc-700 hover:bg-zinc-800 text-white text-sm font-semibold rounded-lg transition-colors">\n                          {t("Şifreyi Güncelle")}\n                        </button>',
    '<button onClick={handleSavePassword} disabled={isSavingSecurity} className="px-6 py-2 bg-[#111111] border border-zinc-700 hover:bg-zinc-800 text-white text-sm font-semibold rounded-lg transition-colors flex items-center justify-center min-w-[150px]">\n                          {isSavingSecurity ? <Loader2 className="w-4 h-4 animate-spin" /> : t("Şifreyi Güncelle")}\n                        </button>'
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated Settings Logic.")
