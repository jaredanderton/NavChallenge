//
//  SearchViewController.swift
//  NavChallenge
//
//  Created by Jared Anderton on 8/12/16.
//  Copyright © 2016 andertondev. All rights reserved.
//

import UIKit
class SearchViewController: ViewController, UISearchBarDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    
    var results:[Movie] = []
    var resultsLoadPage: Int = 0
    var resultsPageCount: Int = 0
    var query: String = ""
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noResultsView: UIView!
    @IBOutlet weak var noResultsLabel, startYouSearchLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        prepareCollectionViewForKeyboard()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBarHidden = true
    }
    
    
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.navigationBarHidden = false
    }
    
    func configureView() {
        handleCurrentResultCount()
        noResultsLabel.addShadow()
        startYouSearchLabel.addShadow()
        removeSearchBackground()
        searchBar.tintColor = UIColor.blackColor()
    }
    
    func removeSearchBackground() {
        for subView in searchBar.subviews {
            for subViewInSubView in subView.subviews {
                if subViewInSubView.isKindOfClass(UITextField) {
                    subViewInSubView.backgroundColor = UIColor.clearColor()
               }
            }
        }
    }
    
    
    func searchMoviesParameters() -> Dictionary<String, AnyObject> {
        var params = Dictionary<String, AnyObject>()
        
        params["api_key"]   = Constants.TheMovieDbApiKey
        params["query"]     = query
        params["page"]      = resultsLoadPage
        
        return params
    }
    
    func resetResults() {
        results.removeAll()
        resultsLoadPage     = 0
        resultsPageCount    = 0
    }
    
    func loadNextPage() {
        // increment the page counter for the next page call
        resultsLoadPage += 1
        
        self.httpManager().GET(
            Movie.searchMoviesUrl(),
            parameters: self.searchMoviesParameters(),
            success: { (operation: AFHTTPRequestOperation, responseObject: AnyObject) in
                
                var tmpMovie: [Movie] = []
                do {
                    let json = try NSJSONSerialization.JSONObjectWithData(operation.responseData!, options: .AllowFragments)
                    if let movies = json.objectForKey("results") as? NSArray {
                        for movieData in movies {
                            let movie = Movie.init(movieData as! Dictionary<String, AnyObject>)
                            tmpMovie.append(movie)
                        }
                    }
                    if let pageNum = json.objectForKey("page") as? Int {
                        // even though we are tracking the page count, 
                        // the api is the source of truth, 
                        // so overwrite the page counter variable on each successful response
                        self.resultsLoadPage = pageNum;
                    }
                    if let pageNumCount = json.objectForKey("total_pages") as? Int {
                        self.resultsPageCount = pageNumCount;
                    }
                } catch {
                    //print("Error \(error)")
                }
                let tmpResults  = self.results
                self.results    = tmpResults + tmpMovie
                self.handleCurrentResultCount()
                
            }, failure: { (operation: AFHTTPRequestOperation?, error: NSError) in
                self.handleHttpFailure(operation!, error: error)
                self.handleCurrentResultCount()
            }
        )
    }
    
    func handleCurrentResultCount() {
        collectionView.reloadData()
        if results.count == 0 {
            UIView.animateWithDuration(0.5) {
                self.collectionView.alpha   = 0.0
                self.noResultsView.alpha    = 1.0
            }
            
            if query.characters.count == 0 {
                self.noResultsLabel.alpha       = 0.0
                self.startYouSearchLabel.alpha  = 1.0
            } else {
                self.noResultsLabel.alpha       = 1.0
                self.startYouSearchLabel.alpha  = 0.0
            }
            
        } else {
            UIView.animateWithDuration(0.5) {                
                self.collectionView.alpha   = 1.0
                self.noResultsView.alpha    = 0.0
            }
        }
    }
    
    
    
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return results.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("SearchResultsCollectionCell", forIndexPath: indexPath) as! SearchCollectionViewCell
        
        let movie   = results[indexPath.item]
        cell.movie  = movie
        if let title = movie.title {
            cell.movieTitleLabel.text = title
            cell.movieTitleLabel.addShadow()
        }
        
        cell.backgroundImageView.image = UIImage(named: "MoviePlaceHolder")
        if let imagePath = movie.poster_path {
            let imageUrl = movie.fullImagePath(imagePath, width: 185)
        
            NSData.getFromCachedFileOrUrl(imageUrl, completion: { (imageData) in
                let downloadedImage             = UIImage(data: imageData)
                cell.backgroundImageView.image  = downloadedImage
                cell.backgroundImageView.setNeedsDisplay()
                
            })
        }
        return cell
    }
    
    
    
    
    
    func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        // only load the next page, if we are about to display the last result we have AND
        // we haven't already reached the number of results limit 
        if indexPath.item == results.count - 1 && resultsLoadPage < resultsPageCount {
            loadNextPage()
        }
    }
    
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
    
        // dynamically size the cells, for consistent size and spacing across different devices
        let screenSize: CGRect  = UIScreen.mainScreen().bounds
        let spacing             = Float(8.0)
        let mult                = Float(2.5)
        let positiveSpace       = Float(screenSize.size.width) - (spacing * mult)
        let w                   = positiveSpace / 2.0
        let h                   = w
        
        return CGSizeMake(CGFloat(w), CGFloat(h))
    }
    
    
                
    
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.httpManager().operationQueue.cancelAllOperations()
        self.resetResults()
        query = ""
        if let text = searchBar.text {
            if text.characters.count > 0 {
                query = text
                self.loadNextPage()
                // if loading the next page, the success will handle the current result count
                return
            }
        }
        handleCurrentResultCount()
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    
    
    
    
    func prepareCollectionViewForKeyboard() {
        edgeInsets = self.collectionView?.contentInset
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(ViewController.keyboardWillShow(_:)),
            name: UIKeyboardWillShowNotification,
            object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(ViewController.keyboardWillHide(_:)),
            name: UIKeyboardWillHideNotification,
            object: nil)
    }
    
    @objc override func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            let contentInsets = UIEdgeInsets(top: edgeInsets!.top, left: 0, bottom: keyboardSize.height, right: 0)
            self.collectionView?.contentInset = contentInsets
            self.collectionView?.scrollIndicatorInsets = contentInsets
        }
    }
    
    @objc override func keyboardWillHide(notification: NSNotification){
        self.collectionView?.contentInset = edgeInsets!
        self.collectionView?.scrollIndicatorInsets = UIEdgeInsetsZero
    }
    
    
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "loadMovieSegue" {
            
            let indexPath   = self.collectionView.indexPathForCell(sender as! SearchCollectionViewCell)
            let movie       = results[(indexPath?.item)!]
            let vc          = segue.destinationViewController as! DetailViewController
            vc.movie        = movie
            
            // stop the search bar from being the first responder,
            // so when navigating back, the scroll point doesn't change
            self.view.endEditing(true)
            
            return
        }
    }
}
