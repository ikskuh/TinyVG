module.exports = {
  full: true,
  multipass: true,
  precision: 3,
  // order of plugins is important to correct functionality
  plugins: [
    'removeDoctype', 
    'removeXMLProcInst', 
    'removeComments', 
    'removeMetadata', 
    'removeEditorsNSData', 
    'cleanupAttrs', 
    'inlineStyles', 
    'minifyStyles', 
    'convertStyleToAttrs', 
    'cleanupIDs', 
    'removeRasterImages', 
    'removeUselessDefs', 
    'cleanupNumericValues', 
    'cleanupListOfValues', 
    'convertColors', 
    'removeUnknownsAndDefaults', 
    'removeNonInheritableGroupAttrs', 
    'removeUselessStrokeAndFill', 
    'cleanupEnableBackground', 
    'removeHiddenElems', 
    'removeEmptyText', 
    'convertShapeToPath', 
    'moveElemsAttrsToGroup', 
    'moveGroupAttrsToElems', 
    'collapseGroups', 
    { 
      name: 'convertPathData',
      params: {
        forceAbsolutePath: true,
      },
    },
    'convertTransform', 
    'removeEmptyAttrs', 
    'removeEmptyContainers', 
    'mergePaths', 
    'removeUnusedNS', 
    'sortAttrs', 
    'removeTitle', 
    'removeDesc', 
    'removeStyleElement', 
    'removeScriptElement', 
  ],
  js2svg: {
    pretty: false,
    indent: ''
  }
};