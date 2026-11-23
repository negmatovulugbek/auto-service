# Auto Service — PWA

## Variant A: GitHub Pages (kompyuterda Flutter shart emas)
1. GitHub'da yangi repo oching (masalan `auto-service`), shu papkadagi hamma fayllarni `main` branchga yuklang.
2. Repo → Settings → Pages → **Source: GitHub Actions** ni tanlang.
3. Actions bo'limida "Deploy PWA" tugashini kuting (~3-5 daqiqa).
4. Manzil: `https://<login>.github.io/<repo>/`
5. https://www.pwabuilder.com ga shu manzilni kiriting → Package for stores.

## Variant B: Kompyuterda qo'lda
    flutter pub get
    flutter build web --release --pwa-strategy=none --no-web-resources-cdn
    # build/web papkasini istalgan hostingga (Netlify, Firebase, Cloudflare Pages) yuklang
    # Hosting ildizda (root) bo'lsa --base-href shart emas.
