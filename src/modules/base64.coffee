convertToBase64 = (url, elem, callback) ->
  if(url.indexOf("data:") >= 0)
    callback null, elem, url
  else
    try
      #console.log "convertToBase64: Url= #{url}"
      xhr = new XMLHttpRequest()
      xhr.open 'GET', url, true
      xhr.responseType = 'blob'
      reader = new FileReader()
      xhr.onload = (e) ->
        #console.log "XHR LOAD"
        if this.status != 200
          callback null, elem, " ", url
        else
          blob = this.response
          reader.onloadend = () ->
            callback null, elem, reader.result, url
          reader.readAsDataURL(blob)
      xhr.onerror = (e) ->
        console.log(
          "XHR Error " +
          e.target.status +
          " occurred while receiving the document."
        )
        callback e, elem, url,url

      xhr.send()
    catch e
      console.log "ConvertToBase64 Error: \n " + e.stack
      callback e, elem, " ", url

module.exports = convertToBase64
