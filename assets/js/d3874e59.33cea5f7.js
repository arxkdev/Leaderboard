"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[374],{3905:(e,t,r)=>{r.d(t,{Zo:()=>m,kt:()=>f});var n=r(67294);function a(e,t,r){return t in e?Object.defineProperty(e,t,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[t]=r,e}function o(e,t){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var n=Object.getOwnPropertySymbols(e);t&&(n=n.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),r.push.apply(r,n)}return r}function l(e){for(var t=1;t<arguments.length;t++){var r=null!=arguments[t]?arguments[t]:{};t%2?o(Object(r),!0).forEach((function(t){a(e,t,r[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):o(Object(r)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(r,t))}))}return e}function c(e,t){if(null==e)return{};var r,n,a=function(e,t){if(null==e)return{};var r,n,a={},o=Object.keys(e);for(n=0;n<o.length;n++)r=o[n],t.indexOf(r)>=0||(a[r]=e[r]);return a}(e,t);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(n=0;n<o.length;n++)r=o[n],t.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(a[r]=e[r])}return a}var i=n.createContext({}),s=function(e){var t=n.useContext(i),r=t;return e&&(r="function"==typeof e?e(t):l(l({},t),e)),r},m=function(e){var t=s(e.components);return n.createElement(i.Provider,{value:t},e.children)},u="mdxType",p={inlineCode:"code",wrapper:function(e){var t=e.children;return n.createElement(n.Fragment,{},t)}},d=n.forwardRef((function(e,t){var r=e.components,a=e.mdxType,o=e.originalType,i=e.parentName,m=c(e,["components","mdxType","originalType","parentName"]),u=s(r),d=a,f=u["".concat(i,".").concat(d)]||u[d]||p[d]||o;return r?n.createElement(f,l(l({ref:t},m),{},{components:r})):n.createElement(f,l({ref:t},m))}));function f(e,t){var r=arguments,a=t&&t.mdxType;if("string"==typeof e||a){var o=r.length,l=new Array(o);l[0]=d;var c={};for(var i in t)hasOwnProperty.call(t,i)&&(c[i]=t[i]);c.originalType=e,c[u]="string"==typeof e?e:a,l[1]=c;for(var s=2;s<o;s++)l[s]=r[s];return n.createElement.apply(null,l)}return n.createElement.apply(null,r)}d.displayName="MDXCreateElement"},4167:(e,t,r)=>{r.r(t),r.d(t,{HomepageFeatures:()=>b,default:()=>y});var n=r(87462),a=r(67294),o=r(3905);const l={toc:[]},c="wrapper";function i(e){let{components:t,...r}=e;return(0,o.kt)(c,(0,n.Z)({},l,r,{components:t,mdxType:"MDXLayout"}),(0,o.kt)("div",{align:"center"},(0,o.kt)("h1",{id:"status"},"Status:"),(0,o.kt)("p",null,"Main code lint status:\n",(0,o.kt)("a",{parentName:"p",href:"https://github.com/arxkdev/Leaderboard/actions/workflows/lint.yaml"},(0,o.kt)("img",{parentName:"a",src:"https://github.com/arxkdev/Leaderboard/actions/workflows/lint.yaml/badge.svg",alt:"Lint"}))),(0,o.kt)("p",null,"Documentation build status:\n",(0,o.kt)("a",{parentName:"p",href:"https://github.com/arxkdev/Leaderboard/actions/workflows/docs.yaml"},(0,o.kt)("img",{parentName:"a",src:"https://github.com/arxkdev/Leaderboard/actions/workflows/docs.yaml/badge.svg",alt:"Documentation"}))),(0,o.kt)("p",null,"Documentation publish status:\n",(0,o.kt)("a",{parentName:"p",href:"https://github.com/arxkdev/Leaderboard/actions/workflows/pages/pages-build-deployment"},(0,o.kt)("img",{parentName:"a",src:"https://github.com/arxkdev/Leaderboard/actions/workflows/pages/pages-build-deployment/badge.svg",alt:"Published"})))))}i.isMDXComponent=!0;var s=r(39960),m=r(52263),u=r(34510),p=r(86010);const d={heroBanner:"heroBanner_e1Bh",buttons:"buttons_VwD3",features:"features_WS6B",featureSvg:"featureSvg_tqLR",titleOnBannerImage:"titleOnBannerImage_r7kd",taglineOnBannerImage:"taglineOnBannerImage_dLPr"},f=[{title:"Simple",description:"Leaderboard is a simple library that allows you to create leaderboards with ease."},{title:"Quick",description:"Leaderboard is a quick library that doesn't hesitiate"},{title:"Lightweight",description:"Leaderboard is a lightweight performance friendly library that doesn't use much memory."}];function g(e){let{image:t,title:r,description:n}=e;return a.createElement("div",{className:(0,p.Z)("col col--4")},t&&a.createElement("div",{className:"text--center"},a.createElement("img",{className:d.featureSvg,alt:r,src:t})),a.createElement("div",{className:"text--center padding-horiz--md"},a.createElement("h3",null,r),a.createElement("p",null,n)))}function b(){return f?a.createElement("section",{className:d.features},a.createElement("div",{className:"container"},a.createElement("div",{className:"row"},f.map(((e,t)=>a.createElement(g,(0,n.Z)({key:t},e))))))):null}function h(){const{siteConfig:e}=(0,m.Z)(),t=e.customFields.bannerImage,r=!!t,n=r?{backgroundImage:`url("${t}")`}:null,o=(0,p.Z)("hero__title",{[d.titleOnBannerImage]:r}),l=(0,p.Z)("hero__subtitle",{[d.taglineOnBannerImage]:r});return a.createElement("header",{className:(0,p.Z)("hero",d.heroBanner),style:n},a.createElement("div",{className:"container"},a.createElement("h1",{className:o},e.title),a.createElement("p",{className:l},e.tagline),a.createElement("div",{className:d.buttons},a.createElement(s.Z,{className:"button button--secondary button--lg",to:"/docs/intro"},"Get Started \u2192"))))}function y(){const{siteConfig:e,tagline:t}=(0,m.Z)();return a.createElement(u.Z,{title:e.title,description:t},a.createElement(h,null),a.createElement("main",null,a.createElement(b,null),a.createElement("div",{className:"container"},a.createElement(i,null))))}}}]);