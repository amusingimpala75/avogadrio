document.addEventListener 'DOMContentLoaded', ->
  # Screen dimensions.
  screenWidth = window.screen.width
  screenHeight = window.screen.height

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

  # Element to use for wallpaper preview.
  previewElement = document.body

  # Download button element.
  downloadButton = document.querySelector '.download-btn'

  # Error message elements.
  errorRows = document.querySelector '.row-error'
  invalidCompoundNameMessage = document.querySelector '.row-error-compound'
  invalidCompoundSmilesMessage = document.querySelector '.row-error-smiles'

  # Gets the sanitized compound name as entered by the user.
  #
  getCompoundName = ->
    encodeURIComponent compoundTextBox.value

  # Gets the sanitized compound SMILES structure as entered by the user.
  #
  getCompoundSmiles = ->
    encodeURIComponent smilesTextBox.value

  # Gets the sanitized custom molecule label as entered by the user.
  #
  getCustomLabel = ->
    encodeURIComponent customLabelTextBox.value

  # URL builder functions for API.

  # Builds a URL to generate a wallpaper image from a compound name.
  #
  # This function is now async
  #
  # @param [int] width          the width of the image
  # @param [int] height         the height of the image
  # @param [string] foreground  the molecule color (hex, without `#`)
  # @param [string] background  the background color (hex, without `#`)
  # @param [name] name          the compound name
  #
  buildUrl = (width, height, foreground, background, name) ->
    smiles = await moleculeName name
    url = "/api/smiles/wallpaper/#{width}/#{height}/#{background}/#{foreground}/#{encodeURIComponent smiles}"
    qs = ""
    if customLabel != '' then qs += "label=#{customLabel}"
    if qs != '' then qs += "&"
    if rotation != 0 then qs += "rotation=#{rotation}"
    return if qs == "" then url else url + "?" + qs

  # Builds a URL to generate a molecule-only image from a compound name.
  #
  # This function is now async
  #
  # @param [int] width          the width of the image if it were rendered as a wallpaper
  # @param [int] height         the height of the image if it were rendered as a wallpaper
  # @param [string] foreground  the molecule color (hex, without `#`)
  # @param [name] name          the compound name
  #
  buildMoleculeOnlyUrl = (width, height, background, foreground, name) ->
    smiles = await moleculeName name
    url = "/api/smiles/molecule/#{width}/#{height}/#{background}/#{foreground}/#{encodeURIComponent smiles}"
    qs = ""
    if customLabel != '' then qs += "label=#{customLabel}"
    if qs != '' then qs += "&"
    if rotation != 0 then qs += "rotation=#{rotation}"
    return if qs == "" then url else url + "?" + qs

  # Builds a URL to generate a wallpaper image from a SMILES structure.
  #
  # @param [int] width          the width of the image
  # @param [int] height         the height of the image
  # @param [string] foreground  the molecule color (hex, without `#`)
  # @param [string] background  the background color (hex, without `#`)
  # @param [name] name          the SMILES structure
  #
  buildSmilesUrl = (width, height, foreground, background, smiles) ->
    url = "/api/smiles/wallpaper/#{width}/#{height}/#{background}/#{foreground}/#{smiles}"
    qs = ""
    if customLabel != '' then qs += "label=#{customLabel}"
    if qs != '' then qs += "&"
    if rotation != 0 then qs += "rotation=#{rotation}"
    return if qs == "" then url else url + "?" + qs

  # Builds a URL to generate a molecule-only image from a SMILES structure.
  #
  # @param [int] width          the width of the image if it were rendered as a wallpaper
  # @param [int] height         the height of the image if it were rendered as a wallpaper
  # @param [string] foreground  the molecule color (hex, without `#`)
  # @param [name] smiles        the SMILES structure
  #
  buildSmilesMoleculeOnlyUrl = (width, height, foreground, background, smiles) ->
    url = "/api/smiles/molecule/#{width}/#{height}/#{background}/#{foreground}/#{smiles}"
    qs = ""
    if customLabel != '' then qs += "label=#{customLabel}"
    if qs != '' then qs += "&"
    if rotation != 0 then qs += "rotation=#{rotation}"
    return if qs == "" then url else url + "?" + qs

  # Checks if a compound name can be converted to SMILES using the configured database.
  #
  # @param [string] name      the compound name
  #
  checkMoleculeName = (name) ->
    return (await moleculeName name) != null

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

  # Updates the download link according to the currently displayed molecule.
  #
  updateDownloadLink = ->
    url = await buildUrl screenWidth, screenHeight, foregroundColor, backgroundColor, currentCompoundName
    if smilesMode
      url = buildSmilesUrl screenWidth, screenHeight, foregroundColor, backgroundColor, currentCompoundSmiles
    downloadButton.setAttribute 'download', if smilesMode then 'smiles_molecule' else currentCompoundName
    downloadButton.setAttribute 'href', url

  # Updates the page URL (query string) according to the currently displayed molecule.
  #
  updateUrl = ->
    params = {
      'label': customLabel,
      'background': backgroundColor,
      'foreground': foregroundColor,
      'rotation': rotation
    }
    if smilesMode
      params['smiles'] = currentCompoundSmiles
    else
      params['compound'] = currentCompoundName
    setQueryParams params

  # Updates the displayed preview.
  #
  # @param [object] element     the element to update
  # @param [string] url         the URL of the image to preview
  # @param [string] background  the background color (hex, without `#`)
  #
  updatePreview = (element, url, background) ->
    element.style.background = "url('#{url}')"
    element.style.backgroundColor = "##{background}"
    element.style.backgroundPosition = '50% 50%'
    element.style.backgroundRepeat = 'no-repeat'
    updateDownloadLink()
    updateUrl()

  # Refreshes the preview using the compound name text box.
  #
  refreshPreviewCompoundName = ->
    currentCompoundName = getCompoundName()
    smilesMode = false
    url = await buildMoleculeOnlyUrl screenWidth, screenHeight, backgroundColor, foregroundColor, currentCompoundName, rotation
    updatePreview previewElement, url, backgroundColor, rotation

  # Refreshes the preview using the SMILES structure text box.
  #
  refreshPreviewSmiles = ->
    currentCompoundSmiles = getCompoundSmiles()
    smilesMode = true
    url = buildSmilesMoleculeOnlyUrl screenWidth, screenHeight, foregroundColor, backgroundColor, currentCompoundSmiles, rotation
    updatePreview previewElement, url, backgroundColor, rotation

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
    if await checkMoleculeName getCompoundName()
      refreshPreviewCompoundName()
    else
      failPreview()

  document.querySelector('.update-smiles-btn').addEventListener 'click', (e) ->
    smilesMode = true
    errorRows.style.display = 'none'
    if checkSmiles getCompoundSmiles()
      refreshPreviewSmiles()
    else
      failPreviewSmiles()

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
