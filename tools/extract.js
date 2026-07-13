// extract.js — 旧版抽出器（div.section のみ拾う）
//
// ⚠️ これは例題 div.example・練習問題 div.problem を取りこぼす既知バグがある旧版。
//    通常は extract3.js を使うこと。互換・参照用に残してある。
(() => {
  function sectionToMd(sec) {
    const clone = sec.cloneNode(true);
    const scripts = Array.from(clone.querySelectorAll('script[type^="math/tex"]'));
    scripts.forEach(s => {
      const tex = s.textContent;
      const display = (s.getAttribute('type')||'').includes('mode=display');
      const wrap = display ? ' $$'+tex+'$$ ' : ' $'+tex+'$ ';
      const repl = document.createTextNode(wrap);
      let prev = s.previousSibling;
      while (prev && prev.nodeType === Node.ELEMENT_NODE && /MathJax/.test(prev.className||'')) {
        const toRemove = prev; prev = prev.previousSibling; toRemove.remove();
      }
      s.replaceWith(repl);
    });
    clone.querySelectorAll('script').forEach(n=>n.remove());
    let txt = clone.textContent.replace(/[ \t]+/g,' ');
    txt = txt.split('\n').map(l=>l.trim()).filter(l=>l.length).join('\n');
    return txt;
  }
  return JSON.stringify(Array.from(document.querySelectorAll('div.section')).map(sectionToMd));
})()
