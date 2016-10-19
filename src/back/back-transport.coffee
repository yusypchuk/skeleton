do ({expect, assert} = chai = require "chai").should
Base64 = require '../modules/base64.coffee'
convertURL = require '../modules/getRelativeLink.coffee'
FileSaver = require 'file-saver'
xhr = require '../modules/xhr.coffee'
gonzales = require '../modules/gonzales.coffee'
select = require('optimal-select').select

META_ATTRIBS_FOR_DEL = [
  'Content-Security-Policy'
  'refresh'
]

ONEVENT_ATTRIBS = [
  'onload'
  'onclick'
  'onkeyup'
  'onkeydown'
  'onenter'
  'onmouseenter',
  'onmouseleave'
  'onkeypress'
]

class TreeElementNotFound extends Error

class BackTransport

  constructor: (@callbackObject) ->
    expect(@callbackObject).to.exist
    @dictionary={}
    @flag = false

    chrome.browserAction.onClicked.addListener () =>
      # This function is executed on the content page and retrieves its HTML
      # content. Function runs on on the body page and each iframes

      console.log "Button pressed!"
      chrome.tabs.query {active: true, currentWindow: true}, (tabArray) =>
        chrome.tabs.executeScript tabArray[0].id,
        file: "content.min.js"
        allFrames: true
        matchAboutBlank: true
        ,(array) =>
          @parse(@callback)
        chrome.runtime.onConnect.addListener (port) =>
          #console.log port.name
          # portname == 'skeleton' ?
          port.onMessage.addListener (message) =>
            console.log message
            @save message.message

  deleteScripts: (document) ->
    scripts = document.querySelectorAll 'script'
    for script in scripts
      script.parentElement.removeChild script
    return document

  deleteAxtElements: (document) ->
    axtElements = document.querySelectorAll('[axt-element]')
    console.log "axtElements =", axtElements
    axtElements.forEach (element) ->
      element.parentElement?.removeChild(element)

  deleteMeta: (document) ->
    metaElements = document.querySelectorAll('meta[http-equiv]')
    metaElements.forEach (element) ->
      if element.getAttribute('http-equiv') in META_ATTRIBS_FOR_DEL
        element.parentElement?.removeChild(element)

  deleteSendBoxAttrib: (document) ->
    iframes = document.querySelectorAll('iframe[sendbox]')
    iframes.forEach (iframe) ->
      iframe.removeAttribute('sendbox')

  deleteAxtAttribs: (document) ->
    body = document.getElementsByTagName('body')[0]
    body.removeAttribute('axt-keyreel-extension-installed')

    axtAttrElements = document.querySelectorAll('[axt-visible]')
    axtAttrElements.forEach (element) ->
      element.removeAttribute('axt-visible')

  replaceAxtAttribs: (document) ->
    document.querySelectorAll('[axt-form-type]').forEach (form) ->
      hardly = form.getAttribute('axt-hardly') == 'true'
      form_type = form.getAttribute('axt-form-type')

      form.removeAttribute('axt-form-type')
      form.removeAttribute('axt-hardly')
      if hardly
        attrib_name = 'axt-hardly-expected-form-type'
      else
        attrib_name = 'axt-expected-form-type'
      form.setAttribute(attrib_name, form_type)

      form.querySelectorAll('[axt-input-type]').forEach (input) ->
        input_type = input.getAttribute('axt-input-type')
        hardly = input.getAttribute('axt-hardly') == 'true'
        input.removeAttribute('axt-input-type')
        input.removeAttribute('axt-hardly')
        if hardly
          attrib_name = 'axt-hardly-expected-input-type'
        else
          attrib_name = 'axt-expected-input-type'
        input.setAttribute(attrib_name, input_type)

      form.querySelectorAll('[axt-button-type]').forEach (button) ->
        button_type = button.getAttribute('axt-button-type')
        hardly = button.getAttribute('axt-hardly') == 'true'
        button.removeAttribute('axt-button-type')
        button.removeAttribute('axt-hardly')
        if hardly
          attrib_name = 'axt-hardly-expected-button-type'
        else
          attrib_name = 'axt-expected-button-type'
        button.setAttribute(attrib_name, button_type)

  clearValueAttrib: (document) ->
    inputs = document.querySelectorAll("input[type='password']")
    inputs.forEach (input) ->
      input.setAttribute('value', '') if input.getAttribute('value')

  clearOnEventAttribs: (document) ->
    elements = document.querySelectorAll(
      "[#{ONEVENT_ATTRIBS.join('],[')}]"
    )
    elements.forEach (element) ->
      for attr in element.attributes
        if attr?.name in ONEVENT_ATTRIBS
          element.removeAttribute(attr.name)

  cleanUp: (document) ->
    #console.log "DOCUMENT=", document
    @deleteScripts(document)
    @deleteMeta(document)
    @clearOnEventAttribs(document)
    @deleteSendBoxAttrib(document)
    @deleteAxtElements(document)
    @deleteAxtAttribs(document)
    @replaceAxtAttribs(document)
    @clearValueAttrib(document)
    return document

  save: (dom) ->
    _html = document.createElement 'html'
    _html.innerHTML = dom[1]
    obj =
      url: dom[0]
      header: dom[2]
      document: @cleanUp _html
      framesIdx: dom[4]
      doctype: dom[5]
    @dictionary[dom[3]] = obj

  callback: (counter, counter1) =>
    #console.log counter
    if counter == 0 and @flag == true and counter1 == 0
      console.log @dictionary
      @createNewObj @dictionary[""],""
      file = new File([
        @getAttribute(
          @dictionary[""].header,@dictionary[""].doctype
        ),
        @dictionary[""].document.innerHTML,
        "</html>"
        ],
        @dictionary[""]
          .document.getElementsByTagName('title')[0]
          .innerHTML + ".html",
        {type: "text/html;charset=utf-8"}
      )
      FileSaver.saveAs(file)
      @flag = false
      @dictionary = {}

  parse: (callback) ->
    #console.warn "DICTINARY",@dictionary
    attributeCounter = 0
    tagCounter = 0
    for key, dom of @dictionary
      tagsStyles = dom.document.querySelectorAll '*[style]'
      for tag in tagsStyles
        attributeCounter++
        gonzales tag.getAttribute('style'), tag, dom.url,
          (error, tag, result) ->
            attributeCounter--
            if error?
              console.error "Style attr error", error
            else
              tag.setAttribute('style', result)
            callback tagCounter, attributeCounter
      tags = dom.document.querySelectorAll 'img,link,style'

      for tag in tags
        tagCounter += 1
        if(tag.hasAttribute('src'))
          src = convertURL tag.getAttribute('src'), dom.url
          Base64 src, tag, (error, tag, result) ->
            tagCounter--
            if error?
              console.error "(src)Base 64 error:", error.stack
            else
              tag.setAttribute "src", result
            callback tagCounter, attributeCounter
        else if(tag.hasAttribute('href'))
          if(tag.getAttribute('rel') == "stylesheet")
            href = convertURL(tag.getAttribute('href'), dom.url)
            gonzales xhr(href), tag, href, (error, tag, result) ->
              if error?
                console.error "style error", error
              else
                #console.log counter
                tagCounter--
                style = document.createElement 'style'
                style.innerHTML = result
                parent = tag.parentElement
                #console.log parent
                #console.log style
                tag.parentElement.insertBefore style, tag
                tag.parentElement.removeChild tag
                #console.log parent.parentElement
              callback tagCounter, attributeCounter
          else
            href = convertURL(tag.getAttribute('href'), dom.url)
            Base64 href, tag, (error, tag, result) ->
              tagCounter--
              if error?
                console.error "(href) Base64 error (href=#{href}):", error.stack
              else
                tag.setAttribute "href", result
              callback tagCounter, attributeCounter
        else
          gonzales tag.innerHTML, tag, dom.url, (error, tag, result) ->
            tagCounter--
            if error?
              console.error "(style)gonzales error:", error.stack
              console.error tag.innerHTML
            else
              tag.innerHTML = result
            callback tagCounter, attributeCounter
    @flag = true

  createNewObj: (obj, str) ->
    console.log "START from", str
    frames = obj.document.getElementsByTagName 'iframe'
    console.log frames
    for frame, i in frames
      selector = select(frame)
      console.log "SELECTOR", selector
      console.log "Obj", obj.framesIdx
      index = -1
      for key of obj.framesIdx
        if selector.indexOf(key) != -1
          index= obj.framesIdx[key]
      if index == -1
        continue
      key = str + index
      console.log "KEY", key
      console.warn @dictionary
      if @dictionary[key]?
        @createNewObj @dictionary[key], key + ":"
        source = @getAttribute(
          @dictionary[key].header,
          @dictionary[key].doctype
        ) + @dictionary[key].document.innerHTML + "</html>"
        frame.setAttribute "srcdoc",  source
        console.log frame
      else
        frame.parentElement.removeChild frame

  getAttribute: (array, status) ->
    src = "<html "
    for i in [0...array.length] by 2
      if array[i+1]?
        src += array[i] + '="' + array[i+1] + '" '
      else
        break
    console.log status
    if status?
      doctype = @getDoctype(status)
      console.log doctype
      return doctype + src
    return src += ">"

  getDoctype: (array) ->
    src = "<!DOCTYPE "
    elem = ""
    for i in [0...array.length]
      if i == 1
        src += "PUBLIC " + '"' + array[i] + '" '
      if i == 2
        src += '"' + array[i] + '"'
      if i == 0
        src+= array[i] + " "
      console.log src
    return src + ">"


module.exports = BackTransport
