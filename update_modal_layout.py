import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

pattern = r'\{\/\* Layout for Settings \*\/\}.*?</AnimatePresence>'

new_layout = """{/* Layout for Settings */}
              <div className="flex flex-1 overflow-hidden h-[500px]">
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
                    onClick={() => setSettingsTab('emails-auth')}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${settingsTab === 'emails-auth' ? 'bg-[#FF5708]/10 text-[#FF5708]' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'}`}
                  >
                    <ShieldCheck className="w-4 h-4" />
                    {t("E-postalar & Auth")}
                  </button>
                  <button 
                    onClick={() => setSettingsTab('guvenlik')}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${settingsTab === 'guvenlik' ? 'bg-[#FF5708]/10 text-[#FF5708]' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'}`}
                  >
                    <Lock className="w-4 h-4" />
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
                    <div className="space-y-8">
                      {/* Avatar Selection */}
                      <div>
                        <h3 className="text-lg font-medium text-white mb-4">{t("Profil Fotoğrafı Seç")}</h3>
                        <div className="flex flex-col gap-6">
                          <div className="flex items-center gap-6">
                            <div className={`w-20 h-20 rounded-full ${avatars[selectedAvatar]} flex items-center justify-center shadow-lg ring-4 ring-[#111111] overflow-hidden`}>
                              <User className="w-8 h-8 text-white/50 mix-blend-overlay" />
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

                      <div className="w-full h-px bg-zinc-800/80 my-2" />

                      {/* Personal Info & Connected Accounts */}
                      <div>
                        <h3 className="text-lg font-medium text-white mb-4">{t("Kişisel Bilgiler")}</h3>
                        <div className="space-y-4 mb-8">
                          <div>
                            <label className="block text-sm font-medium text-zinc-400 mb-1.5">{t("İsim")}</label>
                            <div className="relative">
                              <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                              <input type="text" defaultValue={session?.user?.name || ""} className="w-full bg-[#111111] border border-zinc-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-[#FF5708] focus:ring-1 focus:ring-[#FF5708] transition-all" />
                            </div>
                          </div>
                          <div>
                            <label className="block text-sm font-medium text-zinc-400 mb-1.5">{t("E-posta")}</label>
                            <div className="relative">
                              <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                              <input type="email" disabled defaultValue={session?.user?.email || ""} className="w-full bg-[#111111]/50 border border-zinc-800/50 rounded-lg pl-10 pr-4 py-2.5 text-sm text-zinc-500 cursor-not-allowed" />
                            </div>
                            <p className="text-xs text-zinc-500 mt-2">E-posta adresinizi 'E-postalar & Auth' sekmesinden değiştirebilirsiniz.</p>
                          </div>
                        </div>

                        <h3 className="text-lg font-medium text-white mb-4">{t("Bağlı Platformlar")}</h3>
                        <div className="space-y-3">
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
                        </div>
                      </div>
                      
                      <div className="pt-6 border-t border-zinc-800/80 flex justify-end">
                        <button className="px-6 py-2 bg-[#FF5708] hover:bg-[#ff6c26] text-white text-sm font-semibold rounded-lg transition-colors">
                          {t("Değişiklikleri Kaydet")}
                        </button>
                      </div>
                    </div>
                  )}

                  {/* Emails & Auth Tab */}
                  {settingsTab === 'emails-auth' && (
                    <div className="space-y-8">
                      <div>
                        <h3 className="text-lg font-medium text-white mb-4">{t("İki Aşamalı Doğrulama (2FA)")}</h3>
                        <div className="p-5 rounded-xl bg-zinc-900/40 border border-zinc-800/80">
                          <div className="flex items-start justify-between">
                            <div className="flex items-start gap-4">
                              <div className="w-10 h-10 rounded-full bg-blue-500/10 flex items-center justify-center mt-0.5">
                                <Smartphone className="w-5 h-5 text-blue-400" />
                              </div>
                              <div>
                                <h4 className="text-base font-medium text-white">Authenticator Uygulaması</h4>
                                <p className="text-sm text-zinc-400 mt-1">{t("Hesabınızı ekstra güvenlik katmanıyla koruyun.")}</p>
                                <span className="inline-flex items-center px-2 py-1 rounded-md bg-zinc-800 text-xs font-medium text-zinc-400 mt-3">{t("Pasif")}</span>
                              </div>
                            </div>
                            <button className="px-4 py-2 bg-zinc-100 hover:bg-white text-zinc-900 text-sm font-semibold rounded-lg transition-colors">
                              {t("Aktifleştir")}
                            </button>
                          </div>
                        </div>
                      </div>

                      <div className="w-full h-px bg-zinc-800/80 my-4" />

                      <div>
                        <h3 className="text-lg font-medium text-white mb-4">{t("E-posta Değiştir")}</h3>
                        <div className="space-y-4">
                          <div>
                            <label className="block text-sm font-medium text-zinc-400 mb-1.5">Mevcut E-posta</label>
                            <input type="email" disabled defaultValue={session?.user?.email || ""} className="w-full bg-[#111111]/50 border border-zinc-800/50 rounded-lg px-4 py-2.5 text-sm text-zinc-500 cursor-not-allowed" />
                          </div>
                          <div>
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
                          </div>
                        </div>
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
                      
                      <div className="pt-6 border-t border-zinc-800/80 flex justify-end mt-8">
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
      </AnimatePresence>"""

content = re.sub(pattern, new_layout, content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated Modal Layout with new tabs and contents.")
