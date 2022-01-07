const PRE             = 'nc-cache-app'
const CACHE_NAME      = 'nc-cache-app.2021120717.js'
const DATA_CACHE_NAME = 'nc-cache-app.2021120717.js-data'
const PRE_CACHE = [

    // './index.html',
    // './',
]

self.addEventListener('install', e => {
  console.log('[ServiceWorker] Install')
  e.waitUntil(
    caches.open(CACHE_NAME)
    .then(cache => cache.addAll(PRE_CACHE))
    .then(() => self.skipWaiting())
    .then(() =>{ console.log("skipWaiting.")})
  )
})

self.addEventListener('fetch', e => {
    e.respondWith(
      caches.match(e.request).then(response => {
        if (response) {
          return response
        }
  
        const fetchRequest = e.request.clone()
        /*
        if(fetchRequest.url.indexOf("/bpm/instance/flowImage")>0)
                fetchRequest.headers["Content-Type"] = "image/png";
        */
        return fetch(fetchRequest).then(response => {
          // Check if we received a valid response
          if (!response || response.status !== 200) {
            return response
          }
  
          const responseToCache = response.clone()
  
          if(false
               || e.request.url.indexOf("/node_modules/") >0
               || e.request.method=="GET-X"
            )
          caches.open(DATA_CACHE_NAME).then(cache => {
             cache.put(e.request, responseToCache)
          })
  
          return response
        })
      })
    )
  })

  self.addEventListener('activate', e => {
    e.waitUntil(
      caches.keys().then(keyList => {
        return Promise.all(
          keyList.map(key => {
            if (key !== CACHE_NAME && key !== DATA_CACHE_NAME && key.indexOf(PRE) ===0) {
              console.log('[ServiceWorker] Removing old cache', key)
              return caches.delete(key)
            }
          })
        )
      })
      .then(()=>{
        console.dir("activated ！ All Done ！");

      })
    )
  })
