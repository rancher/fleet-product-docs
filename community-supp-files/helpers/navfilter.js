'use strict'

const extractModuleFromURL = (url, componentName) => {
  const position = (componentName === 'ROOT') ? 2 : 3
  const value = url.split('/')[position] || null
  return value
}
const findModule = (nav, module) =>
  (nav.url && extractModuleFromURL(nav.url) === module) ||
  (Array.isArray(nav.items) && nav.items.some((item) => findModule(item, module)))

module.exports = (navList, module) => navList.filter((nav) => findModule(nav, module))
