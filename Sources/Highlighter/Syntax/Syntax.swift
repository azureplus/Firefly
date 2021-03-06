//
//  Languages.swift
//  
//
//  Created by Zachary lineman on 12/24/20.
//

import UIKit

public class Syntax {
    var currentLanguage: String = "default" {
        didSet(value) {
            setLanguage(to: value)
        }
    }
    var currentTheme: String = "Basic" {
        didSet(value) {
            setTheme(to: value)
        }
    }
    var currentFont: UIFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    var fontSize: CGFloat = UIFont.systemFontSize
    
    var definitions: [Definition] = []
    var theme: Theme = Theme(defaultFontColor: UIColor.black, backgroundColor: UIColor.white, currentLine: UIColor.clear, selection: UIColor.blue, cursor: UIColor.blue, colors: [:], font: UIFont.systemFont(ofSize: UIFont.systemFontSize), style: .light, lineNumber: UIColor.white, lineNumber_Active: UIColor.white)
    
    init(language: String, theme: String, font: String) {
        currentLanguage = language
        currentTheme = theme
        setFont(to: font)
    }
    
    func setLanguage(to name: String) {
        if let language = languages[name.lowercased()] {
            for item in language {
                let type = item.key
                let dict: [String: Any] = item.value as! [String : Any]
                let regex: String = dict["regex"] as? String ?? ""
                let group: Int = dict["group"] as? Int ?? 0
                let relevance: Int = dict["relevance"] as? Int ?? 0
                let options: [NSRegularExpression.Options] = dict["options"] as? [NSRegularExpression.Options] ?? []
                let multi: Bool = dict["multiline"] as? Bool ?? false

                definitions.append(Definition(type: type, regex: regex, group: group, relevance: relevance, matches: options, multiLine: multi))
            }
        }
        var editorPlaceholderPattern = "(<#)([^\"\\n]*?)"
        editorPlaceholderPattern += "(#>)"

        definitions.sort { (def1, def2) -> Bool in return def1.relevance > def2.relevance }
        definitions.insert(Definition(type: "placeholder", regex: editorPlaceholderPattern, group: 0, relevance: 10, matches: [], multiLine: false), at: 0)
        definitions.reverse()
        
    }
    
    func setTheme(to name: String) {
        if let theme = themes[name] {
            let defaultColor = UIColor(hex: (theme["default"] as? String) ?? "#000000")
            let backgroundColor = UIColor(hex: (theme["background"] as? String) ?? "#000000")
            
            let currentLineColor = UIColor(hex: (theme["currentLine"] as? String) ?? "#000000")
            let selectionColor = UIColor(hex: (theme["selection"] as? String) ?? "#000000")
            let cursorColor = UIColor(hex: (theme["cursor"] as? String) ?? "#000000")
            
            let lineNumber = UIColor(hex: (theme["lineNumber"] as? String) ?? "#000000")
            let lineNumber_Active = UIColor(hex: (theme["lineNumber-Active"] as? String) ?? "#000000")

            let styleRaw = theme["style"] as? String
            let style: Theme.UIStyle = styleRaw == "light" ? .light : .dark

            var colors: [String: UIColor] = [:]
            
            if let cDefs = theme["definitions"] as? [String: String] {
                for item in cDefs {
                    colors.merge([item.key: UIColor(hex: (item.value))]) { (first, _) -> UIColor in return first }
                }
            }
            
            self.theme = Theme(defaultFontColor: defaultColor, backgroundColor: backgroundColor, currentLine: currentLineColor, selection: selectionColor, cursor: cursorColor, colors: colors, font: currentFont, style: style, lineNumber: lineNumber, lineNumber_Active: lineNumber_Active)
        }
    }
    /*
     "default": "#3c3836", // editor.foreground
     "background": "#f9f5d7", // editor.background
     "currentLine": "#ebdbb260", // editor.lineHighlightBackground
     "selection": "#689d6a40", // editor.selectionBackground
     "cursor": "#3c3836", // editorCursor.foreground
     "lineNumber": "#bdae93", // editorLineNumber.foreground
     "lineNumber-Active": "#bdae93", // editorLineNumber.activeForeground

     */
    
    func setFont(to name: String) {
        if name == "system" {
            currentFont = UIFont.systemFont(ofSize: fontSize)
        } else {
            currentFont = UIFont(name: name, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        }
        setTheme(to: currentTheme)
    }
    
    func getHighlightColor(for type: String) -> UIColor {
        return theme.colors[type] ?? theme.defaultFontColor
    }
    
    public static func highlightAttributedString(string: NSAttributedString, theme: Theme, language: String) -> NSMutableAttributedString {
        var definitions: [Definition] = []
        if let language = languages[language] {
            for item in language {
                let type = item.key
                let dict: [String: Any] = item.value as! [String : Any]
                let regex: String = dict["regex"] as? String ?? ""
                let group: Int = dict["group"] as? Int ?? 0
                let relevance: Int = dict["relevance"] as? Int ?? 0
                let options: [NSRegularExpression.Options] = dict["options"] as? [NSRegularExpression.Options] ?? []
                let multi: Bool = dict["multiline"] as? Bool ?? false

                definitions.append(Definition(type: type, regex: regex, group: group, relevance: relevance, matches: options, multiLine: multi))
            }
        }
        
        definitions.sort { (def1, def2) -> Bool in return def1.relevance > def2.relevance }
        definitions.reverse()

        let nsString = NSMutableAttributedString(attributedString: string)
        let totalRange = NSRange(location: 0, length: nsString.string.count)
        nsString.setAttributes([NSAttributedString.Key.foregroundColor: theme.defaultFontColor, NSAttributedString.Key.font: theme.font], range: totalRange)
        
        for item in definitions {
            var regex = try? NSRegularExpression(pattern: item.regex)
            if let option = item.matches.first {
                regex = try? NSRegularExpression(pattern: item.regex, options: option)
            }
            if let matches = regex?.matches(in: nsString.string, options: [], range: totalRange) {
                for aMatch in matches {
                    let color = theme.colors[item.type] ?? theme.defaultFontColor
                    nsString.addAttributes([NSAttributedString.Key.foregroundColor: color, NSAttributedString.Key.font: theme.font], range: aMatch.range(at: item.group))
                }
            }
        }

        return nsString
    }
}
