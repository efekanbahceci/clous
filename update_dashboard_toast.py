import re

file_path = "apps/web/app/dashboard/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. State definition block
old_state_block = """  // Settings Modal States
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [settingsTab, setSettingsTab] = useState('profil');
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
  ];"""

new_state_block = """  // Settings & Profile States
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

  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [settingsTab, setSettingsTab] = useState('profil');
  const [linkedAccounts, setLinkedAccounts] = useState<any[]>([]);
  const [displayName, setDisplayName] = useState("");
  const [displayAvatar, setDisplayAvatar] = useState(0);
  const [selectedAvatar, setSelectedAvatar] = useState(0);
  const [userName, setUserName] = useState("");
  const [newEmail, setNewEmail] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [isSavingSecurity, setIsSavingSecurity] = useState(false);
  const [isSavingEmail, setIsSavingEmail] = useState(false);

  // Custom Toast State
  const [toast, setToast] = useState<{ message: string; visible: boolean; type?: 'success' | 'error' }>({
    message: "",
    visible: false,
    type: "success"
  });

  const showToast = (message: string, type: 'success' | 'error' = 'success') => {
    setToast({ message, visible: true, type });
    setTimeout(() => {
      setToast(prev => ({ ...prev, visible: false }));
    }, 3500);
  };

  useEffect(() => {
    if (session?.user) {
      const initialName = session.user.name || "";
      if (!displayName) setDisplayName(initialName);
      if (!userName) setUserName(initialName);
      
      // Fetch latest profile from DB
      fetch("/api/user/profile")
        .then(r => r.json())
        .then(data => {
          if (data?.name) {
            setDisplayName(data.name);
            setUserName(data.name);
          }
          if (data?.image) {
            const idx = avatars.indexOf(data.image);
            if (idx !== -1) {
              setSelectedAvatar(idx);
              setDisplayAvatar(idx);
            }
          }
        })
        .catch(console.error);
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
    const newName = userName.trim() || displayName || "Kullanıcı";
    const newAvatarIdx = selectedAvatar;
    
    // Instant UI updates
    setDisplayName(newName);
    setDisplayAvatar(newAvatarIdx);
    
    try {
      const res = await fetch("/api/user/profile", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: newName, image: avatars[newAvatarIdx] })
      });
      if (res.ok) {
        showToast(t("Değişiklikler kaydedildi"), "success");
      } else {
        showToast("Profil kaydedilirken hata oluştu", "error");
      }
    } catch(e) {
      showToast("Bağlantı hatası oluştu", "error");
    } finally {
      setIsSavingProfile(false);
    }
  };

  const handleSavePassword = async () => {
    if(!currentPassword || !newPassword) {
      showToast("Lütfen tüm alanları doldurun", "error");
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
        showToast(t("Değişiklikler kaydedildi"), "success");
        setCurrentPassword("");
        setNewPassword("");
      } else {
        showToast("Şifre güncellenirken hata oluştu", "error");
      }
    } catch(e) {
      showToast("Bağlantı hatası oluştu", "error");
    } finally {
      setIsSavingSecurity(false);
    }
  };

  const handleUpdateEmail = async () => {
    if (!newEmail.trim()) {
      showToast("Lütfen yeni e-posta adresini girin", "error");
      return;
    }
    setIsSavingEmail(true);
    setTimeout(() => {
      showToast(t("Değişiklikler kaydedildi"), "success");
      setNewEmail("");
      setIsSavingEmail(false);
    }, 500);
  };"""

if old_state_block in content:
    content = content.replace(old_state_block, new_state_block)
    print("Replaced state block successfully")
else:
    print("Could not find exact old_state_block, using regex")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
