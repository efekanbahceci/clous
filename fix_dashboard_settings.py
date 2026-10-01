import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add Icons needed
if "User," not in content:
    content = content.replace('import { Terminal', 'import { User, Settings, Shield, Globe, Lock, Key, Brush, Check, Image as ImageIcon, Camera } from "lucide-react";\nimport { Terminal')
else:
    # Just to be safe, add them if missing
    content = content.replace('import { Terminal', 'import { User, Settings, Shield, Globe, Lock, Key, Brush, Check, Image as ImageIcon, Camera } from "lucide-react";\nimport { Terminal')

# 2. Add states for Settings
settings_states = """  const [isModalOpen, setIsModalOpen] = useState(false);
  
  // Settings Modal States
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [settingsTab, setSettingsTab] = useState('profil');
  const [selectedAvatar, setSelectedAvatar] = useState(0);
  const avatars = [
    "bg-gradient-to-br from-red-500 to-orange-500",
    "bg-gradient-to-br from-blue-500 to-purple-500",
    "bg-gradient-to-br from-green-400 to-emerald-600",
    "bg-gradient-to-br from-pink-500 to-rose-500",
    "bg-gradient-to-br from-indigo-500 to-cyan-400",
    "bg-gradient-to-br from-amber-400 to-orange-600",
    "bg-gradient-to-br from-fuchsia-600 to-purple-600",
    "bg-gradient-to-br from-teal-400 to-emerald-500",
    "bg-gradient-to-br from-violet-500 to-fuchsia-500",
    "bg-gradient-to-br from-slate-600 to-zinc-800"
  ];
"""
content = content.replace('  const [isModalOpen, setIsModalOpen] = useState(false);', settings_states)

# 3. Modify "Ayarlar" button in sidebar (and mobile menu if exists)
# Find: <span className="font-medium">{t("Ayarlar")}</span>
# Replace its parent button onClick
content = re.sub(
    r'<button\s+className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800/50 transition-colors text-left">\s*<Settings className="w-4 h-4" />\s*<span className="font-medium">\{t\("Ayarlar"\)\}</span>\s*</button>',
    r'<button onClick={() => setIsSettingsOpen(true)} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800/50 transition-colors text-left"><Settings className="w-4 h-4" /><span className="font-medium">{t("Ayarlar")}</span></button>',
    content
)

# 4. Create Settings Modal JSX
settings_modal = """
      {/* Ayarlar Modal */}
      <AnimatePresence>
        {isSettingsOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsSettingsOpen(false)}
              className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            />
            
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 10 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 10 }}
              className="bg-[#111111] border border-zinc-800/80 rounded-2xl w-full max-w-3xl max-h-[85vh] flex flex-col relative z-10 shadow-2xl overflow-hidden"
            >
              {/* Header */}
              <div className="flex items-center justify-between p-6 border-b border-zinc-800/80">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-zinc-800/50 flex items-center justify-center">
                    <Settings className="w-5 h-5 text-[#FF5708]" />
                  </div>
                  <div>
                    <h2 className="text-xl font-semibold text-white">{t("Ayarlar")}</h2>
                    <p className="text-sm text-zinc-400">Hesap ve proje tercihlerinizi yönetin.</p>
                  </div>
                </div>
                <button 
                  onClick={() => setIsSettingsOpen(false)}
                  className="p-2 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Layout for Settings */}
              <div className="flex flex-1 overflow-hidden">
                {/* Settings Sidebar */}
                <div className="w-48 sm:w-56 border-r border-zinc-800/80 bg-zinc-900/20 p-4 space-y-1 overflow-y-auto">
                  <button 
                    onClick={() => setSettingsTab('profil')}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${settingsTab === 'profil' ? 'bg-[#FF5708]/10 text-[#FF5708]' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'}`}
                  >
                    <User className="w-4 h-4" />
                    {t("Profil")}
                  </button>
                  <button 
                    onClick={() => setSettingsTab('guvenlik')}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${settingsTab === 'guvenlik' ? 'bg-[#FF5708]/10 text-[#FF5708]' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'}`}
                  >
                    <Shield className="w-4 h-4" />
                    {t("Güvenlik")}
                  </button>
                  <button 
                    onClick={() => setSettingsTab('projeler')}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${settingsTab === 'projeler' ? 'bg-[#FF5708]/10 text-[#FF5708]' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'}`}
                  >
                    <FolderKanban className="w-4 h-4" />
                    {t("Proje Ayarları")}
                  </button>
                </div>

                {/* Settings Content */}
                <div className="flex-1 overflow-y-auto p-6 bg-[#0a0a0a]">
                  
                  {/* Profil Tab */}
                  {settingsTab === 'profil' && (
                    <div className="space-y-6">
                      <div>
                        <h3 className="text-lg font-medium text-white mb-4">{t("Profil Fotoğrafı Seç")}</h3>
                        <div className="flex flex-col gap-6">
                          <div className="flex items-center gap-6">
                            <div className={`w-24 h-24 rounded-full ${avatars[selectedAvatar]} flex items-center justify-center shadow-lg ring-4 ring-[#111111] overflow-hidden`}>
                              <User className="w-10 h-10 text-white/50 mix-blend-overlay" />
                            </div>
                            <div className="text-sm text-zinc-400">
                              <p className="mb-1">Platformdaki görünümünüzü kişiselleştirin.</p>
                              <p>Hazır 10 farklı renk paletinden birini seçebilirsiniz.</p>
                            </div>
                          </div>
                          
                          <div className="grid grid-cols-5 gap-4">
                            {avatars.map((avatar, index) => (
                              <button
                                key={index}
                                onClick={() => setSelectedAvatar(index)}
                                className={`relative w-full aspect-square rounded-2xl ${avatar} transition-transform hover:scale-105 active:scale-95 ${selectedAvatar === index ? 'ring-2 ring-[#FF5708] ring-offset-2 ring-offset-[#0a0a0a]' : ''}`}
                              >
                                {selectedAvatar === index && (
                                  <div className="absolute inset-0 bg-black/20 rounded-2xl flex items-center justify-center backdrop-blur-[1px]">
                                    <Check className="w-6 h-6 text-white" />
                                  </div>
                                )}
                              </button>
                            ))}
                          </div>
                        </div>
                      </div>
                      
                      <div className="pt-6 border-t border-zinc-800/80 flex justify-end">
                        <button className="px-6 py-2 bg-[#FF5708] hover:bg-[#ff6c26] text-white text-sm font-semibold rounded-lg transition-colors">
                          {t("Değişiklikleri Kaydet")}
                        </button>
                      </div>
                    </div>
                  )}

                  {/* Güvenlik Tab */}
                  {settingsTab === 'guvenlik' && (
                    <div className="space-y-6">
                      <h3 className="text-lg font-medium text-white mb-4">{t("Şifreyi Güncelle")}</h3>
                      <div className="space-y-4">
                        <div>
                          <label className="block text-sm font-medium text-zinc-400 mb-1.5">{t("Eski Şifre")}</label>
                          <div className="relative">
                            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                            <input type="password" placeholder="••••••••" className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />
                          </div>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-zinc-400 mb-1.5">{t("Yeni Şifre")}</label>
                          <div className="relative">
                            <Key className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                            <input type="password" placeholder="••••••••" className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />
                          </div>
                        </div>
                      </div>
                      
                      <div className="pt-6 border-t border-zinc-800/80 flex justify-end">
                        <button className="px-6 py-2 bg-[#111111] border border-zinc-700 hover:bg-zinc-800 text-white text-sm font-semibold rounded-lg transition-colors">
                          {t("Şifreyi Güncelle")}
                        </button>
                      </div>
                    </div>
                  )}

                  {/* Projeler Tab */}
                  {settingsTab === 'projeler' && (
                    <div className="space-y-6">
                      <h3 className="text-lg font-medium text-white mb-4">{t("Proje Ayarları")}</h3>
                      
                      <div className="space-y-4">
                        <div className="flex items-center justify-between p-4 rounded-xl bg-[#111111] border border-zinc-800/80">
                          <div>
                            <h4 className="text-sm font-medium text-white">{t("Otomatik Dağıtım")}</h4>
                            <p className="text-xs text-zinc-500 mt-0.5">{t("Projeleriniz için otomatik build süreçlerini aktifleştirin.")}</p>
                          </div>
                          <div className="w-10 h-6 bg-[#FF5708] rounded-full relative cursor-pointer">
                            <div className="absolute right-1 top-1 w-4 h-4 bg-white rounded-full" />
                          </div>
                        </div>

                        <div className="flex items-center justify-between p-4 rounded-xl bg-[#111111] border border-zinc-800/80">
                          <div>
                            <h4 className="text-sm font-medium text-white">{t("Gelişmiş Analitik")}</h4>
                            <p className="text-xs text-zinc-500 mt-0.5">{t("Proje trafik verilerini detaylı analiz edin.")}</p>
                          </div>
                          <div className="w-10 h-6 bg-zinc-700 rounded-full relative cursor-pointer">
                            <div className="absolute left-1 top-1 w-4 h-4 bg-white rounded-full" />
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                </div>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
"""

# Inject before the final closing div (assuming </div>\n  );\n})
content = re.sub(r'(\s*</div>\s*);\s*}', settings_modal + r'\1', content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Updated dashboard settings modal")
