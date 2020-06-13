//
//  SidebarTableView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 5/5/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

import UIKit
import NightNight
import AudioToolbox

@IBDesignable
class SidebarTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource,
    UITableViewDropDelegate {

    @IBInspectable var startColor:   UIColor = .black { didSet { updateColors() }}
    @IBInspectable var endColor:     UIColor = .white { didSet { updateColors() }}
    @IBInspectable var startLocation: Double =   0.05 { didSet { updateLocations() }}
    @IBInspectable var endLocation:   Double =   0.95 { didSet { updateLocations() }}
    @IBInspectable var horizontalMode:  Bool =  false { didSet { updatePoints() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { updatePoints() }}

    var gradientLayer: CAGradientLayer { return layer as! CAGradientLayer }
    private var sidebar: Sidebar = Sidebar()
    private var busyTrashReloading = false

    public var viewController: ViewController?

    override class var layerClass: AnyClass { return CAGradientLayer.self }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePoints()
        updateLocations()
        updateColors()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sidebar.items.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sidebar.items[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "sidebarCell", for: indexPath) as! SidebarTableCellView

        guard sidebar.items.indices.contains(indexPath.section), sidebar.items[indexPath.section].indices.contains(indexPath.row) else { return cell }

        let sidebarItem = sidebar.items[indexPath.section][indexPath.row]
        cell.configure(sidebarItem: sidebarItem)
        cell.contentView.setNeedsLayout()
        cell.contentView.layoutIfNeeded()

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            let custom = UIView()
            view.backgroundView = custom

            var font: UIFont = UIFont.systemFont(ofSize: 15)

            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font)
            }

            view.textLabel?.font = font.bold()
            view.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            let custom = UIView()
            view.backgroundView = custom
            
            var font: UIFont = UIFont.systemFont(ofSize: 15)
            
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font)
            }
            
            view.textLabel?.font = font.bold()
            view.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 37
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let vc = self.viewController else { return }

        vc.turnOffSearch()

        let sidebarItem = sidebar.items[indexPath.section][indexPath.row]

        if sidebarItem.name == NSLocalizedString("Settings", comment: "Sidebar settings") {
            Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false) { _ in
                vc.openSettings()
                self.deselectRow(at: indexPath, animated: false)
            }

            AudioServicesPlaySystemSound(1519)
            return
        }

        var name = sidebarItem.name
        if sidebarItem.type == .Category || sidebarItem.type == .Inbox || sidebarItem.type == .All {
            name += " ▽"
        }

        let project =
            sidebarItem.type == .Tag
                ? vc.searchQuery.project
                : sidebarItem.project

        let tag =
            sidebarItem.type == .Tag
                ? sidebarItem.name
                : nil

        vc.searchQuery =
            SearchQuery(
                type: sidebarItem.type,
                project: project,
                tag: tag
            )

        vc.currentFolder.text = name

        if sidebarItem.isTrash() {
            if !busyTrashReloading {
                busyTrashReloading = true
            } else {
                return
            }

            let storage = Storage.sharedInstance()
            storage.reLoadTrash()

            if !vc.isActiveTableUpdating {
                vc.reloadNotesTable(with: SearchQuery(type: .Trash)) {
                    self.busyTrashReloading = false
                }
            }

            return
        }

        guard !vc.isActiveTableUpdating else { return }

        vc.reloadNotesTable(with: vc.searchQuery) {
            if sidebarItem.project != nil {
                self.loadAllTags()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.clear
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)

        if let sidebarCell = cell as? SidebarTableCellView {
            if let sidebarItem = (cell as! SidebarTableCellView).sidebarItem, sidebarItem.type == .Tag || sidebarItem.type == .Category {
                sidebarCell.icon.constraints[1].constant = 0
                sidebarCell.labelConstraint.constant = 0
                sidebarCell.contentView.setNeedsLayout()
                sidebarCell.contentView.layoutIfNeeded()
            }
        }
    }

    public func deselectAll() {
        if let paths = indexPathsForSelectedRows {
            for path in paths {
                deselectRow(at: path, animated: false)
            }
        }
    }

    public func select(indexPath: IndexPath) {
        guard let vc = viewController else { return }

        selectRow(at: indexPath, animated: false, scrollPosition: .none)
        let item = sidebar.items[indexPath.section][indexPath.row]

        var name = item.name
        if item.type == .Category
            || item.type == .Inbox
            || item.type == .All {
            name += " ▽"
        }

        vc.searchQuery = SearchQuery(type: item.type, project: item.project, tag: item.name)
        vc.currentFolder.text = name
    }

    // MARK: Gradient settings
    func updatePoints() {
        if horizontalMode {
            gradientLayer.startPoint = diagonalMode ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint   = diagonalMode ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0.5)
        } else {
            gradientLayer.startPoint = diagonalMode ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint   = diagonalMode ? CGPoint(x: 1, y: 1) : CGPoint(x: 0.5, y: 1)
        }
    }

    func updateLocations() {
        gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
    }

    func updateColors() {
        if NightNight.theme == .night{
            let startNightTheme = UIColor(red:0.14, green:0.14, blue:0.14, alpha:1.0)
            let endNightTheme = UIColor(red:0.12, green:0.11, blue:0.12, alpha:1.0)

            gradientLayer.colors    = [startNightTheme.cgColor, endNightTheme.cgColor]
        } else {
            gradientLayer.colors    = [startColor.cgColor, endColor.cgColor]
        }
    }

    public func getSidebarItem(project: Project? = nil) -> SidebarItem? {

        if let project = project, sidebar.items.count > 1 {
            return sidebar.items[1].first(where: { $0.project == project })
        }

        guard let indexPath = indexPathForSelectedRow else { return nil }

        let item = sidebar.items[indexPath.section][indexPath.row]

        return item
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {

        guard let vc = viewController else { return }
        guard let indexPath = coordinator.destinationIndexPath, let cell = tableView.cellForRow(at: indexPath) as? SidebarTableCellView else { return }

        guard let sidebarItem = cell.sidebarItem else { return }

        _ = coordinator.session.loadObjects(ofClass: String.self) { item in
            let pathList = item as [String]

            for path in pathList {
                let url = URL(fileURLWithPath: path)
                
                guard let note = Storage.sharedInstance().getBy(url: url) else { continue }

                switch sidebarItem.type {
                case .Category, .Archive, .Inbox:
                    guard let project = sidebarItem.project else { break }
                    self.move(note: note, in: project)
                case .Trash:
                    note.remove()
                    vc.notesTable.removeRows(notes: [note])
                case .Tag:
                    note.addTag(sidebarItem.name)
                default:
                    break
                }
            }

            vc.notesTable.isEditing = false
        }
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {

        guard let indexPath = destinationIndexPath,
            let cell = tableView.cellForRow(at: indexPath) as? SidebarTableCellView,
            let sidebarItem = cell.sidebarItem
        else { return UITableViewDropProposal(operation: .cancel) }

        if sidebarItem.project != nil || sidebarItem.type == .Trash || sidebarItem.type == .Tag {
            return UITableViewDropProposal(operation: .copy)
        }

        return UITableViewDropProposal(operation: .cancel)
    }

    private func move(note: Note, in project: Project) {
        guard let vc = viewController else { return }

        let dstURL = project.url.appendingPathComponent(note.name)

        if note.project != project {
            note.moveImages(to: project)
            
            guard note.move(to: dstURL) else {
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: "File with this name already exist", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                vc.present(alert, animated: true, completion: nil)

                note.moveImages(to: note.project)
                return
            }

            note.url = dstURL
            note.invalidateCache()
            note.parseURL()
            note.project = project

            vc.notesTable.removeRows(notes: [note])
            vc.notesTable.insertRows(notes: [note])
        }
    }

    public func getSidebarProjects() -> [Project]? {
        guard let indexPaths = UIApplication.getVC().sidebarTableView?.indexPathsForSelectedRows else { return nil }

        var projects = [Project]()
        for indexPath in indexPaths {
            let item = sidebar.items[indexPath.section][indexPath.row]
            if let project = item.project {
                projects.append(project)
            }
        }

        if projects.count > 0 {
            return projects
        }

        if let root = Storage.sharedInstance().getRootProject() {
            return [root]
        }

        return nil
    }

    public func getAllTags(projects: [Project]? = nil) -> [String] {
        var tags = [String]()

        if let projects = projects {
            for project in projects {
                let projectTags = project.getAllTags()
                for tag in projectTags {
                    if !tags.contains(tag) {
                        tags.append(tag)
                    }
                }
            }
        }

        return tags.sorted()
    }

    public func loadAllTags() {
        guard UserDefaultsManagement.inlineTags, let vc = viewController else { return }
        
        unloadAllTags()
        guard let project = vc.searchQuery.project else { return }

        let tags = getAllTags(projects: [project])
        guard tags.count > 0 else { return }

        DispatchQueue.main.async {
            for tag in tags {
                let position = self.sidebar.items[2].count
                let element = SidebarItem(name: tag, type: .Tag)
                self.sidebar.items[2].insert(element, at: position)
            }

            self.viewController?.resizeSidebar()
            self.safeReloadData()
        }
    }

    public func unloadAllTags() {
        guard sidebar.items[2].count > 0 else { return }

        let rows = numberOfRows(inSection: 2)

        if rows > 0 {
            self.sidebar.items[2].removeAll()

            self.beginUpdates()
            for index in stride(from: rows - 1, to: -1, by: -1) {
                self.deleteRows(at: [IndexPath(item: index, section: 2)], with: .automatic)
            }
            self.endUpdates()
        }
    }

    public func reloadProjectsSection() {
        sidebar.updateProjects()
        safeReloadData()
    }

    public func getSelectedSidebarItem() -> SidebarItem? {
        guard let vc = viewController, let project = vc.searchQuery.project else { return nil }
        let items = sidebar.items

        for item in items {
            for subItem in item {
                if subItem.project == project {
                    return subItem
                }
            }
        }

        return nil
    }

    public func safeReloadData() {
        var currentProject: Project?
        var tagName: String?

        if let section = indexPathForSelectedRow?.section,
            let row = indexPathForSelectedRow?.row {

            currentProject = sidebar.items[section][row].project

            if section == SidebarSection.Tags.rawValue {
                tagName = sidebar.items[SidebarSection.Tags.rawValue][row].name
            }
        }

        reloadData()

        for (sectionId, section) in sidebar.items.enumerated() {
            for (rowId, item) in section.enumerated() {
                if let project = currentProject, item.project === project {
                    let indexPath = IndexPath(row: rowId, section: sectionId)
                    selectRow(at: indexPath, animated: false, scrollPosition: .none)
                    return
                }

                if sectionId == SidebarSection.Tags.rawValue,
                    let name = tagName, item.name == name
                {
                    let indexPath = IndexPath(row: rowId, section: sectionId)
                    selectRow(at: indexPath, animated: false, scrollPosition: .none)
                    return
                }
            }
        }
    }

    public func getIndexPathBy(project: Project) -> IndexPath? {
        for (sectionId, section) in sidebar.items.enumerated() {
            for (rowId, item) in section.enumerated() {
                if item.project === project {
                    let indexPath = IndexPath(row: rowId, section: sectionId)
                    return indexPath
                }
            }
        }

        return nil
    }

    public func getIndexPathBy(tag: String) -> IndexPath? {
        let tagsSection = SidebarSection.Tags.rawValue

        for (rowId, item) in sidebar.items[tagsSection].enumerated() {
            if item.name == tag {
                let indexPath = IndexPath(row: rowId, section: tagsSection)
                return indexPath
            }
        }

        return nil
    }

    public func removeRows(projects: [Project]) {
        guard projects.count > 0, let vc = viewController else { return }
        var deselectCurrent = false

        for project in projects {
            if project == vc.searchQuery.project {
                deselectCurrent = true
            }

            vc.storage.remove(project: project)
        }

        reloadProjectsSection()

        if deselectCurrent {

            vc.notesTable.notes.removeAll()
            vc.notesTable.reloadData()

            let indexPath = IndexPath(row: 0, section: 0)
            select(indexPath: indexPath)
        }
    }
}
