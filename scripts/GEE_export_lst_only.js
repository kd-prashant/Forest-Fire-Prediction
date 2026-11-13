// ============================================================
// GEE_export_lst_only.js
//
// Simplified LST-only export script with null value handling.
// Paste this into GEE Code Editor and run.
// ============================================================

// --- District centroids (Lon, Lat) ---
var nainital      = ee.Geometry.Point([79.4542, 29.3919]);
var pauri_garhwal = ee.Geometry.Point([78.7795, 29.7767]);
var almora        = ee.Geometry.Point([79.6531, 29.5971]);
var tehri_garhwal = ee.Geometry.Point([78.4322, 30.3783]);
var chamoli       = ee.Geometry.Point([79.3193, 30.4124]);

// Put them in a list so we can loop through
var points = [nainital, pauri_garhwal, almora, tehri_garhwal, chamoli];
var names  = ['Nainital', 'Pauri_Garhwal', 'Almora', 'Tehri_Garhwal', 'Chamoli'];

// --- Date range ---
var start = '2019-01-01';
var end   = '2024-12-31';

// --- Load MODIS LST (8-day composite, 1km resolution) ---
var lst_collection = ee.ImageCollection('MODIS/061/MOD11A2')
  .filterDate(start, end)
  .select('LST_Day_1km');

// --- For each image, extract LST at each district centroid ---
var lst_features = lst_collection.map(function(image) {
  var date = image.date().format('YYYY-MM-dd');

  // Build a feature for each district point
  var feature_list = ee.List([
    ee.Feature(null, {
      district: 'Nainital',
      date: date,
      lst: image.reduceRegion({
        reducer: ee.Reducer.mean(), geometry: nainital, scale: 1000
      }).get('LST_Day_1km')
    }),
    ee.Feature(null, {
      district: 'Pauri_Garhwal',
      date: date,
      lst: image.reduceRegion({
        reducer: ee.Reducer.mean(), geometry: pauri_garhwal, scale: 1000
      }).get('LST_Day_1km')
    }),
    ee.Feature(null, {
      district: 'Almora',
      date: date,
      lst: image.reduceRegion({
        reducer: ee.Reducer.mean(), geometry: almora, scale: 1000
      }).get('LST_Day_1km')
    }),
    ee.Feature(null, {
      district: 'Tehri_Garhwal',
      date: date,
      lst: image.reduceRegion({
        reducer: ee.Reducer.mean(), geometry: tehri_garhwal, scale: 1000
      }).get('LST_Day_1km')
    }),
    ee.Feature(null, {
      district: 'Chamoli',
      date: date,
      lst: image.reduceRegion({
        reducer: ee.Reducer.mean(), geometry: chamoli, scale: 1000
      }).get('LST_Day_1km')
    })
  ]);

  return ee.FeatureCollection(feature_list);
}).flatten();

// Note: LST raw values need scale factor 0.02 applied, then subtract 273.15 for Celsius.
// We export raw values here and convert in R (safer — avoids null math errors in GEE).
// In R: lst_celsius = (raw_value * 0.02) - 273.15

// --- Export to Google Drive as CSV ---
Export.table.toDrive({
  collection: lst_features,
  description: 'LST_Uttarakhand_2019_2024',
  fileNamePrefix: 'lst_uttarakhand',
  fileFormat: 'CSV',
  folder: 'GEE_Exports',
  selectors: ['district', 'date', 'lst']
});

print('LST export task created!');
print('Go to Tasks tab → click RUN → folder: GEE_Exports → click Run');
print('Note: LST values are RAW (scale factor 0.02 applied in R, not here)');
