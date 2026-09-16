document.addEventListener 'DOMContentLoaded', ->
  # Download canvas dimensions.
  downloadWidth = 1920
  downloadHeight = 1080

  # Wallpaper color attributes.
  foregroundColor = 'ce3838'
  backgroundColor = '5f0000'

  # Transforms.
  rotation = 0

  # Custom label for molecule.
  customLabel = ''

  # Data about current molecule.
  smilesMode = true
  currentCompoundName = ''
  currentCompoundSmiles = 'CCN(CC)C1=CC2=C(C=C1)N=C3C4=CC=CC=C4C(=O)C=C3O2'

  # Text entry fields for molecules.
  compoundTextBox = document.querySelector '.comp-name'
  smilesTextBox = document.querySelector '.comp-smiles'
  customLabelTextBox = document.querySelector '.cust-lbl-tbox'

  # Element to use for the SVG wallpaper preview.
  previewElement = document.querySelector '#smiles-svg'

  # Download button element and its current object URL.
  downloadButton = document.querySelector '.download-btn'
  downloadUrl = null

  # Error message elements.
  errorRows = document.querySelector '.row-error'
  invalidCompoundNameMessage = document.querySelector '.row-error-compound'
  invalidCompoundSmilesMessage = document.querySelector '.row-error-smiles'

  # Gets the compound data as entered by the user. The raw values are needed by
  # SmilesDrawer; query-string encoding is applied only when the page URL changes.
  #
  getCompoundName = ->
    compoundTextBox.value

  getCompoundSmiles = ->
    smilesTextBox.value

  getCustomLabel = ->
    customLabelTextBox.value

  # Gets a compound SMILES if its name is found in configured databases.
  #
  # @param [string] name      the compound name
  #
  moleculeName = (name) ->
    cactus = await cactusMoleculeName name
    if cactus != null
      return cactus
    return await wikipediaMoleculeName name

  # Gets a compound SMILES if its name is in the Cactus SMILES database, else null
  #
  # @param [string] name      the compound name
  #
  cactusMoleculeName = (name) ->
    uri = "https://cactus.nci.nih.gov/chemical/structure/#{encodeURIComponent(name)}/smiles"
    try
      response = await fetch(uri)
      data = await response.text()
      if checkSmiles data
        return data
      else
        return null
    catch error
      return null

  # Gets a compound SMILES from its name if it is in Wikipedia, else null
  #
  # @param [string] name      the compound name
  #
  wikipediaMoleculeName = (name) ->
    uri = "https://en.wikipedia.org/w/api.php?action=parse&format=json&page=#{encodeURIComponent(name)}&prop=text&origin=*"
    try
      response = await fetch(uri)
      data = await response.json()
      html = data.parse.text["*"]
      doc = new DOMParser().parseFromString(html, 'text/html')
      for a in doc.querySelectorAll('a')
        if a.textContent.includes('SMILES')
          container = a.closest('.mw-collapsible')
          smiles = container?.querySelector('li')?.textContent.trim()
          if checkSmiles smiles
            return smiles
      return null
    catch error
      return null

  # Checks if a string is a valid SMILES structure.
  #
  # @param [string] name      the compound name
  #
  checkSmiles = (smiles) ->
    regex = /^([^J][a-z0-9@+\.\-\[\]\(\)\\\/%=#$]{0,})$/ig
    return regex.test smiles

  # Checks if a string is a valid hex color.
  #
  # @param [string] color the color to check
  #
  checkColor = (color) ->
    regex = /^(([0-9a-fA-F]{2}){3}|([0-9a-fA-F]){3})$/ig
    regex.test color

  # Actions to take when we refresh the preview.

  # Shows the invalid compound name error message.
  #
  failPreview = ->
    invalidCompoundNameMessage.show()

  # Shows the invalid smiles structure error message.
  #
  failPreviewSmiles = ->
    invalidCompoundSmilesMessage.show()

  # Updates the download link with a PNG rendered from the 1920x1080 SVG.
  #
  updateDownloadLink = ->
    svg = new XMLSerializer().serializeToString previewElement
    image = new Image()
    image.onload = ->
      canvas = document.createElement 'canvas'
      canvas.width = downloadWidth
      canvas.height = downloadHeight
      canvas.getContext('2d').drawImage image, 0, 0, downloadWidth, downloadHeight
      canvas.toBlob (blob) ->
        URL.revokeObjectURL(downloadUrl) if downloadUrl != null
        downloadUrl = URL.createObjectURL blob
        filename = if smilesMode then 'smiles_molecule.png' else "#{currentCompoundName}.png"
        downloadButton.setAttribute 'download', filename
        downloadButton.setAttribute 'href', downloadUrl
      , 'image/png'
    image.src = "data:image/svg+xml;charset=utf-8,#{encodeURIComponent(svg)}"

  # Updates the page URL (query string) according to the currently displayed molecule.
  #
  updateUrl = ->
    params = {
      'label': encodeURIComponent(customLabel),
      'background': backgroundColor,
      'foreground': foregroundColor,
      'rotation': rotation
    }
    if smilesMode
      params['smiles'] = encodeURIComponent(currentCompoundSmiles)
    else
      params['compound'] = encodeURIComponent(currentCompoundName)
    setQueryParams params

  # Renders a SMILES structure as a self-contained wallpaper SVG. SmilesDrawer
  # draws into a nested SVG so its content can be centered within the fixed-size
  # wallpaper canvas.
  #
  renderSmiles = (smiles, onError = failPreviewSmiles) ->
    SmilesDrawer.parse smiles, (tree) ->
      namespace = 'http://www.w3.org/2000/svg'
      createElement = (name) -> document.createElementNS namespace, name
      foreground = "##{foregroundColor}"
      theme = {}
      for element in ['C', 'O', 'N', 'F', 'CL', 'BR', 'I', 'P', 'S', 'B', 'SI', 'H']
        theme[element] = foreground
      theme.BACKGROUND = "##{backgroundColor}"

      molecule = createElement 'svg'
      drawer = new SmilesDrawer.SvgDrawer {
        themes:
          light: theme
      }
      drawer.draw tree, molecule, 'light'
      molecule.style.width = ''
      molecule.style.height = ''
      molecule.setAttribute 'x', 192
      molecule.setAttribute 'y', 108
      molecule.setAttribute 'width', 1536
      molecule.setAttribute 'height', 864
      molecule.setAttribute 'preserveAspectRatio', 'xMidYMid meet'

      while previewElement.firstChild
        previewElement.removeChild previewElement.firstChild
      previewElement.setAttribute 'xmlns', namespace
      previewElement.setAttribute 'width', downloadWidth
      previewElement.setAttribute 'height', downloadHeight
      previewElement.setAttribute 'viewBox', "0 0 #{downloadWidth} #{downloadHeight}"

      document.documentElement.style.backgroundColor = "##{backgroundColor}"
      document.body.style.backgroundColor = "##{backgroundColor}"

      background = createElement 'rect'
      background.setAttribute 'width', '100%'
      background.setAttribute 'height', '100%'
      background.setAttribute 'fill', "##{backgroundColor}"
      previewElement.appendChild background

      drawing = createElement 'g'
      drawing.setAttribute 'transform', "rotate(#{rotation} #{downloadWidth / 2} #{downloadHeight / 2})"
      drawing.appendChild molecule
      if customLabel != ''
        label = createElement 'text'
        label.setAttribute 'x', downloadWidth / 2
        label.setAttribute 'y', downloadHeight - 48
        label.setAttribute 'fill', foreground
        label.setAttribute 'font-size', 32
        label.setAttribute 'text-anchor', 'middle'
        label.textContent = customLabel
        drawing.appendChild label
      previewElement.appendChild drawing

      updateDownloadLink()
      updateUrl()
    , -> onError()

  # Refreshes the preview using the compound name text box.
  #
  refreshPreviewCompoundName = ->
    currentCompoundName = getCompoundName()
    smilesMode = false
    smiles = await moleculeName currentCompoundName
    if smiles != null
      renderSmiles smiles, failPreview
    else
      failPreview()

  # Refreshes the preview using the SMILES structure text box.
  #
  refreshPreviewSmiles = ->
    currentCompoundSmiles = getCompoundSmiles()
    smilesMode = true
    renderSmiles currentCompoundSmiles

  # Refreshes the preview using the compound name or SMILES structure text box depending on mode.
  #
  modeAwareRefreshPreview = ->
    if smilesMode then refreshPreviewSmiles() else refreshPreviewCompoundName()

  passedForeground = getParameterByName 'foreground'
  if passedForeground != null && checkColor(passedForeground)
    foregroundColor = passedForeground

  passedBackground = getParameterByName 'background'
  if passedBackground != null && checkColor(passedBackground)
    backgroundColor = passedBackground

  # Initialize the Coloris fields with the selected colors. Coloris watches
  # these native input events to keep its swatches in sync.
  Coloris { themeMode: 'dark', alpha: false, theme: 'polaroid' }
  foregroundPicker = document.querySelector '#picker-fg'
  backgroundPicker = document.querySelector '#picker-bg'
  foregroundPicker.value = "##{foregroundColor}"
  backgroundPicker.value = "##{backgroundColor}"
  foregroundPicker.dispatchEvent new Event 'input', bubbles: true
  backgroundPicker.dispatchEvent new Event 'input', bubbles: true

  # Set up color picker change events.
  foregroundPicker.addEventListener 'change', (e) ->
    foregroundColor = e.target.value.substring(1)
    modeAwareRefreshPreview()

  backgroundPicker.addEventListener 'change', (e) ->
    backgroundColor = e.target.value.substring(1)
    modeAwareRefreshPreview()

  # Set up the rotation knob.

  rotationKnob = pureknob.createKnob(88, 88)
  rotationKnob.setProperty 'angleStart', 0
  rotationKnob.setProperty 'angleEnd', Math.PI * 2
  rotationKnob.setProperty 'colorFG', '#C0C0C0'
  rotationKnob.setProperty 'colorBG', '#505050'
  rotationKnob.setProperty 'trackWidth', 0.4
  rotationKnob.setProperty 'valMin', 0
  rotationKnob.setProperty 'valMax', 359
  rotationKnob.setProperty 'needle', true
  rotationKnob.setValue 0
  rotationKnob.addListener (knob, value) ->
    rotation = value
    modeAwareRefreshPreview()
  knobNode = rotationKnob.node()
  knobElem = document.getElementById 'rotation_knob'
  knobElem.appendChild knobNode

  # Compound name update button should refresh the preview.

  document.querySelector('.update-btn').addEventListener 'click', (e) ->
    errorRows.style.display = 'none'
    refreshPreviewCompoundName()

  document.querySelector('.update-smiles-btn').addEventListener 'click', (e) ->
    smilesMode = true
    errorRows.style.display = 'none'
    refreshPreviewSmiles()

  # Label update button should also refresh preview.

  document.querySelector('.update-lbl-btn').addEventListener 'click', (e) ->
    customLabel = getCustomLabel()
    modeAwareRefreshPreview()

  # Put passed parameter values into UI if needed.

  passedCompoundName = getParameterByName 'compound'
  if passedCompoundName != null
    compoundTextBox.value = passedCompoundName
    smilesMode = false

  passedSmiles = getParameterByName 'smiles'
  if passedSmiles != null
    smilesTextBox.value = passedSmiles
    smilesMode = true

  passedLabel = getParameterByName 'label'
  if passedLabel != null
    customLabelTextBox.value = passedLabel

  passedRotation = getParameterByName 'rotation'
  if passedRotation != null
    rotationKnob.setValue(passedRotation)

  # Grab initial values from UI.

  currentCompoundName = compoundTextBox.value
  currentCompoundSmiles = smilesTextBox.value
  customLabel = customLabelTextBox.value
  rotation = rotationKnob.getValue()

  # Initial update.
  modeAwareRefreshPreview()
