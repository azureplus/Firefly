//
//  FireflySyntaxView.swift
//  Refly
//
//  Created by Zachary lineman on 9/27/20.
//

import UIKit

public class FireflySyntaxView: UIView {
    
    ///The highlighting language
    @IBInspectable
    internal var language: String = "default"
    
    ///The highlighting theme name
    @IBInspectable
    internal var theme: String = "Basic"
    
    /// The name of the highlighters font
    @IBInspectable
    internal var fontName: String = "system"
    
    /// If set, sets the text views text to the given text. If gotten gets the text views text.
    @IBInspectable
    public var text: String {
        get {
            return textView.text
        }
        set(nText) {
            textView.text = nText
            textStorage.highlight(NSRange(location: 0, length: textStorage.string.count), cursorRange: nil)
            if dynamicGutterWidth {
                updateGutterWidth()
            }
            textView.selectedRange = NSRange(location: 0, length: 0)
        }
    }
    
    /// The minimum / standard gutter width. Becomes the minimum if dynamicGutterWidth is true otherwise it is the standard gutterWidth
    @IBInspectable
    internal var gutterWidth: CGFloat = 20
    
    /// If set the view will use a dynamic gutter width
    @IBInspectable
    internal var dynamicGutterWidth: Bool = true
    
    /// The views offset from the top of the keyboard
    @IBInspectable
    internal var keyboardOffset: CGFloat = 20
    
    /// Set to true if the view should be offset when the keyboard opens and closes.
    @IBInspectable
    internal var shouldOffsetKeyboard: Bool = false
    
    @IBInspectable
    internal var maxTokenLength: Int = 30000
    
    @IBInspectable
    internal var placeholdersAllowed: Bool = false

    @IBInspectable
    internal var linkPlaceholders: Bool = false
    
    /// The delegate that allows for you to get access the UITextViewDelegate from outside this class !
    /// !!DO NOT CHANGE textViews Delegate directly!!!
    public var delegate: FireflyDelegate? {
        didSet {
            delegate?.didChangeText(textView)
        }
    }
    
    public var textView: FireflyTextView!
    
    internal var textStorage = SyntaxAttributedString(syntax: Syntax(language: "default", theme: "Basic", font: "system"))
    
    internal var layoutManager = LineNumberLayoutManager()
    
    internal var shouldHighlightOnChange: Bool = false
    
    internal var highlightAll: Bool = false
    
    internal var lastChar: Character?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupNotifs()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
        setupNotifs()
    }
    
    /// Sets up the basic parts of the view
    private func setup() {
        //Setup the Text storage and layout managers and actually add the textView to the screen.
        layoutManager.textStorage = textStorage
        textStorage.addLayoutManager(layoutManager)

        //This caused a ton of issues. Has to be the greatest finite magnitude so that the text container is big enough. Not setting to greatest finite magnitude would cause issues with text selection.
        let containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.lineBreakMode = .byWordWrapping
        
        layoutManager.addTextContainer(textContainer)
        let tFrame = CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        textView = FireflyTextView(frame: tFrame, textContainer: textContainer)
        textView.isScrollEnabled = true
        textView.text = ""
        
        self.addSubview(textView)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        textView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        textView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        // Sets default values for the text view to make it more like an editor.
        textView.autocapitalizationType = .none
        textView.keyboardType = .default
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        if self.textStorage.syntax.theme.style == .dark {
            textView.keyboardAppearance = .dark
        } else {
            textView.keyboardAppearance = .light
        }
        textView.delegate = self
    }
    
    /// Sets up keyboard movement notifications
    func setupNotifs() {
        if shouldOffsetKeyboard {
            let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        }
    }
    
    /// This detects keyboards height and adjusts the view to account for the keyboard in the way.
    @objc func adjustForKeyboard(notification: Notification) {
        if shouldOffsetKeyboard {
            guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
            
            let keyboardScreenEndFrame = keyboardValue.cgRectValue
            let keyboardViewEndFrame = self.convert(keyboardScreenEndFrame, from: self.window)
            
            if notification.name == UIResponder.keyboardWillHideNotification {
                textView.contentInset = .zero
            } else {
                let top = textView.contentInset.top; let left = textView.contentInset.left; let right = textView.contentInset.right
                textView.contentInset = UIEdgeInsets(top: top, left: left, bottom: keyboardViewEndFrame.height + keyboardOffset, right: right)
            }
            textView.scrollIndicatorInsets = textView.contentInset
            
            let selectedRange = textView.selectedRange
            textView.scrollRangeToVisible(selectedRange)
        }
    }
    
    /// Force highlights the current range
    public func forceHighlight() {
        print("Force Highlight")
        textStorage.highlight(getVisibleRange(), cursorRange: textView.selectedRange)
    }
    
    /// Reset Highlighting
    public func resetHighlighting() {
        textStorage.resetView()
    }
    
    /// Just updates the views appearence
    private func updateAppearence() {
        textView.backgroundColor = textStorage.syntax.theme.backgroundColor
        textView.tintColor = textStorage.syntax.theme.cursor
        textStorage.highlight(NSRange(location: 0, length: textStorage.string.count), cursorRange: nil)
        if textStorage.syntax.theme.style == .dark {
            textView.keyboardAppearance = .dark
        } else {
            textView.keyboardAppearance = .light
        }
    }
    
   /// Returns the current theme so you can get colors from that
    public func getCurrentTheme() -> Theme {
        return textStorage.syntax.theme
    }
    
    /// Returns the given theme so you can get colors from that
    static public func getTheme(name: String) -> Theme? {
        if let theme = themes[name] {
            let defaultColor = UIColor(hex: (theme["default"] as? String) ?? "#000000")
            let backgroundColor = UIColor(hex: (theme["background"] as? String) ?? "#000000")
            
            let currentLineColor = UIColor(hex: (theme["currentLine"] as? String) ?? "#000000")
            let selectionColor = UIColor(hex: (theme["selection"] as? String) ?? "#000000")
            let cursorColor = UIColor(hex: (theme["cursor"] as? String) ?? "#000000")
            
            let styleRaw = theme["style"] as? String
            let style: Theme.UIStyle = styleRaw == "light" ? .light : .dark

            let lineNumber = UIColor(hex: (theme["lineNumber"] as? String) ?? "#000000")
            let lineNumber_Active = UIColor(hex: (theme["lineNumber-Active"] as? String) ?? "#000000")

            var colors: [String: UIColor] = [:]
            
            if let cDefs = theme["definitions"] as? [String: String] {
                for item in cDefs {
                    colors.merge([item.key: UIColor(hex: (item.value))]) { (first, _) -> UIColor in return first }
                }
            }
            
            return Theme(defaultFontColor: defaultColor, backgroundColor: backgroundColor, currentLine: currentLineColor, selection: selectionColor, cursor: cursorColor, colors: colors, font: UIFont.systemFont(ofSize: UIFont.systemFontSize), style: style, lineNumber: lineNumber, lineNumber_Active: lineNumber_Active)
        }
        return nil
     }
    
    /// Retuns the name of every available theme
    static public func availableThemes() -> [String] {
        var arr: [String] = []
        for item in themes {
            arr.append(item.key)
        }
        return arr
    }
    
    /// Retuns the name of every available theme
    static public func availableLanguages() -> [String] {
        var arr: [String] = []
        for item in languages {
            arr.append(item.key)
        }
        return arr
    }
    
    public func setup(theme: String, language: String, font: String, offsetKeyboard: Bool, keyboardOffset: CGFloat, dynamicGutter: Bool, gutterWidth: CGFloat, placeholdersAllowed: Bool, linkPlaceholders: Bool) {
        self.language = language
        textStorage.syntax.setLanguage(to: language)
        self.fontName = font
        textStorage.syntax.setFont(to: font)
        self.shouldOffsetKeyboard = offsetKeyboard
        self.keyboardOffset = keyboardOffset
        self.dynamicGutterWidth = dynamicGutter
        self.placeholdersAllowed = placeholdersAllowed
        textStorage.placeholdersAllowed = placeholdersAllowed
        self.linkPlaceholders = linkPlaceholders
        textStorage.linkPlaceholders = linkPlaceholders
        self.theme = theme
        textStorage.syntax.setTheme(to: theme)
        layoutManager.theme = textStorage.syntax.theme

        updateAppearence()
    }
    
    /// Sets the theme of the view. Supply with a theme name
    public func setTheme(name: String) {
        theme = name
        textStorage.syntax.setTheme(to: name)
        layoutManager.theme = textStorage.syntax.theme
        updateAppearence()
    }
    
    /// Sets the language that is highlighted
    public func setLanguage(nLanguage: String) {
        language = nLanguage
        textStorage.syntax.setLanguage(to: nLanguage)
        updateAppearence()
    }
    
    /// Sets the font of the highlighter. Should be set to a font name, or "system" for the system.
    public func setFont(font: String) {
        fontName = font
        textStorage.syntax.setFont(to: font)
        updateAppearence()
    }
    
    /// Sets the gutter width.
    public func setShouldOffsetKeyboard(bool: Bool) {
        self.shouldOffsetKeyboard = bool
        setupNotifs()
    }
    
    /// Sets the gutter width.
    public func setGutterWidth(width: CGFloat) {
        self.gutterWidth = width
        textView.gutterWidth = gutterWidth
        layoutManager.gutterWidth = gutterWidth
    }
    
    /// Sets dynamicGutterWidth
    public func setDynamicGutter(bool: Bool) {
        self.dynamicGutterWidth = bool
        updateGutterWidth()
    }
    
    /// Sets the Keyboard Offset
    public func setKeyboardOffset(offset: CGFloat) {
        self.keyboardOffset = offset
    }
    
    /// Sets the max token length
    public func setMaxTokenLength(length: Int) {
        self.maxTokenLength = length
        textStorage.maxTokenLength = length
    }
    
    /// Sets placeholders allowed
    public func setPlaceholdersAllowed(bool: Bool) {
        self.placeholdersAllowed = bool
        textStorage.placeholdersAllowed = bool
    }
    
    /// Tells the view if it links should also be links
    public func setLinkPlaceholders(bool: Bool) {
        self.linkPlaceholders = bool
        textStorage.linkPlaceholders = bool
    }

    
    /// Detects the proper width needed for the gutter.  Can be turned off by setting dynamicGutterWidth to false
    func updateGutterWidth() {
        let components = text.components(separatedBy: .newlines)
        let count = components.count
        let maxNumberOfDigits = "\(count)".count
        
        let leftInset: CGFloat = 4.0
        let rightInset: CGFloat = 4.0
        let charWidth: CGFloat = 10.0
        let newWidth = CGFloat(maxNumberOfDigits) * charWidth + leftInset + rightInset
        
        if newWidth != gutterWidth {
            gutterWidth = newWidth
            textView.setNeedsDisplay()
        }
    }
}
