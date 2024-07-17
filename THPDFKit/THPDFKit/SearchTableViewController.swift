//
//  SearchTableViewController.swift
//  THPDFKit
//
//  Created by Hannes Tribus on 01/02/2018.
//  Copyright © 2018 3Bus. All rights reserved.
//

import UIKit
import PDFKit

@available(iOS 11.0, *)
public protocol SearchTableViewControllerDelegate: class {
    func searchTableViewController(_ searchTableViewController: SearchTableViewController, didSelectSerchResult selection: PDFSelection, row:Int)
    func saveSearchTerm(_ term: String)
}

@available(iOS 11.0, *)
open class SearchTableViewController: UITableViewController {
    
    let searchTableViewCellReuseIdentifier = "SearchTableViewCell"
    
    var isFirstLoad:Bool = false
    var lastSearchTerm:String?
    var lastSelectedRow:Int?
    static let PDF_SEARCH_INDEX:String = "PDF_PERSISTED_INDEX"

    lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.showsCancelButton = true
        searchBar.searchBarStyle = .minimal
        
        return searchBar
    }()
    
    var searchResults = [PDFSelection]()
    
    open var pdfDocument: PDFDocument?
    open var delegate: SearchTableViewControllerDelegate?

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.cellLayoutMarginsFollowReadableWidth = false
        
        navigationItem.titleView = searchBar

        if #available(iOS 13.0, *) {
            searchBar.searchTextField.delegate = self
        } else {
            // Fallback on earlier versions
        }
        
        tableView.register(SearchTableViewCell.classForCoder(), forCellReuseIdentifier: searchTableViewCellReuseIdentifier)
        
        if let lastSearch = self.lastSearchTerm {
            self.isFirstLoad = true
            searchBar.text = lastSearch
            searchBar.becomeFirstResponder()
            runSearch(term: lastSearch)
        }
        
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchBar.becomeFirstResponder()
    }
    
    open override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func cancelButtonClicked(sender: UIBarButtonItem) {
        cancelPressed()
    }
    
    fileprivate func cancelPressed() {
        pdfDocument?.cancelFindString()
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource
    
    open override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return searchResults.count
    }
    
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: searchTableViewCellReuseIdentifier, for: indexPath) as! SearchTableViewCell
        
        let selection = searchResults[indexPath.row]
        let page = selection.pages[0]
        let outline = pdfDocument?.outlineItem(for: selection)
        
        let outlintstr = outline?.label ?? ""
        let pagestr = page.label ?? ""
        let txt = outlintstr + " \(NSLocalizedString("Page", comment: "To be translated")):  " + pagestr
        cell.destinationLabel.text = txt
        
        let extendSelection = selection.copy() as! PDFSelection
        extendSelection.extend(atStart: 10)
        extendSelection.extend(atEnd: 90)
        extendSelection.extendForLineBoundaries()
        
        let range = (extendSelection.string! as NSString).range(of: selection.string!, options: .caseInsensitive)
        let attrstr = NSMutableAttributedString(string: extendSelection.string!)
        attrstr.addAttribute(.backgroundColor, value: UIColor.yellow, range: range)
        
        cell.resultTextLabel.attributedText = attrstr
        
        return cell
    }
    
    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selection = searchResults[indexPath.row]
        
        delegate?.searchTableViewController(self, didSelectSerchResult: selection, row:indexPath.row)
        dismiss(animated: false, completion: nil)
    }
    
    open override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
}

@available(iOS 11.0, *)
extension SearchTableViewController: UISearchBarDelegate, UITextFieldDelegate {
    
    func runSearch(term:String, onViewLoad:Bool = false) {
        searchResults.removeAll()
        tableView.reloadData()
        if let pdfDocument = pdfDocument {
            pdfDocument.cancelFindString()
            pdfDocument.delegate = self
            pdfDocument.beginFindString(term, withOptions: .caseInsensitive)
        }
    }
    
    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        searchResults.removeAll()
        tableView.reloadData()
        return true
    }
    
    open func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    open func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancelPressed()
    }
    
    open func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        if searchText.count < 2 {
            self.delegate?.saveSearchTerm("")
            return
        }
        
        runSearch(term: searchText)
    }
    
}

@available(iOS 11.0, *)
extension SearchTableViewController: PDFDocumentDelegate {
    
    open func didMatchString(_ instance: PDFSelection) {
        searchResults.append(instance)
        if let searchTerm = instance.string {
            self.delegate?.saveSearchTerm(searchTerm)
        }
        
        tableView.reloadData()
        
        if(self.isFirstLoad) {
            self.isFirstLoad = false
            if let lastIndex = self.lastSelectedRow {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    self.tableView.scrollToRow(at: IndexPath(row: lastIndex, section: 0), at: .top, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                        if let cell = self.tableView.cellForRow(at: IndexPath(row: lastIndex, section: 0)), self.tableView.visibleCells.contains(cell) {
                            cell.setHighlighted(true, animated: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                                guard let selected = self.tableView.indexPathForSelectedRow else { return }
                                self.tableView?.deselectRow(at: selected, animated: true)
                            })
                        }
                    })
                })
            }
        }
    }
    
}
