// extract3.js — ZEN Study (nnn.ed.nico) 教材テキスト抽出器（★推奨版）
//
// 何をするか:
//   MathJax(v2) の教材ページから、本文セクション＋例題・練習問題・定義・定理等の
//   全ボックスを「出現順」に拾い、数式は script[type="math/tex"] の元 LaTeX を
//   $...$ / $$...$$ に置換して返す（MathJax の3重重複を回避）。
//   番号（「問題2-2-1」等）は CSS ::before 生成でDOMテキストに無いため、
//   data-zen-number 属性から取る。
//
// 使い方: agent-browser の eval に食わせる（tools/fetch_text.sh 参照）。
//   ⚠️ 抽出前に必ず details を open し「解答を表示」ボタンを click しておくこと
//      （解答が <details> で隠れているため）。fetch_text.sh がやってくれる。
//
// 出力: JSON 文字列。[{kind, num, md}, ...]
//   kind = ボックス種別（section/example/problem/...）, num = data-zen-number, md = 本文
//
// 既知バグ: ディスプレイ数式($$...$$)の直前にレンダリング済みテキストが
//   ゴミ1行漏れることがある（例 Γ(x)=∫∞0... の行）。書き起こし時に手で除去する。
(() => {
  function md(sec){const c=sec.cloneNode(true);
    c.querySelectorAll('script[type^="math/tex"]').forEach(s=>{const t=s.textContent;
      const d=(s.getAttribute('type')||'').includes('mode=display');
      const r=document.createTextNode(d?' $$'+t+'$$ ':' $'+t+'$ ');
      let p=s.previousSibling;while(p&&p.nodeType===1&&/MathJax/.test(p.className||'')){const x=p;p=p.previousSibling;x.remove();}
      s.replaceWith(r);});
    c.querySelectorAll('script').forEach(n=>n.remove());
    return c.textContent.replace(/[ \t]+/g,' ').split('\n').map(l=>l.trim()).filter(l=>l).join('\n');}
  const sel='div.section, div.intro, div.summary, [data-zen-number], div.problem, div.example, div.definition, div.theorem, div.proposition, div.proof, div.hint, div.answer, div.note';
  const seen=new Set(), out=[];
  document.querySelectorAll(sel).forEach(n=>{
    if(seen.has(n))return;
    let p=n.parentElement,nested=false;
    while(p){if(p.matches&&p.matches(sel)){nested=true;break;}p=p.parentElement;}
    if(nested)return; seen.add(n);
    const cls=(n.className||'').toString(), kind=cls.split(/\s+/)[0]||n.tagName.toLowerCase();
    out.push({kind, num:n.getAttribute('data-zen-number')||'', md:md(n)});
  });
  return JSON.stringify(out);
})()
