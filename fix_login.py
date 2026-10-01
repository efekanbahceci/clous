with open("apps/web/app/login/page.tsx", "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "Zaten hesabınız var mı?" in line:
        lines[i] = '                    {isSignUp ? `${t("Zaten hesabınız var mı?")} ${t("Giriş Yapın")}` : `${t("Henüz hesabınız yok mu?")} ${t("Kayıt Olun")}`}\n'
    if "Hoş Geldiniz" in line:
        lines[i] = '                  <h2 className="text-2xl font-semibold text-white">{t("Hoş Geldiniz")}</h2>\n'
    if "t(t(\"Clous" in line:
        lines[i] = '                    {isSignUp ? t("Hesap Oluştur") : t("Clous\'a Giriş Yap")}\n'
        
with open("apps/web/app/login/page.tsx", "w") as f:
    f.writelines(lines)
