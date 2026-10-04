//
//  VeLogsListController.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "VeLogsListController.h"
#import <Preferences/PSSpecifier.h>
#import "../../../Manager/LogManager.h"
#import "../../../Manager/Log.h"
#import "Sorter/ApplicationSorter.h"
#import "Sorter/DateSorter.h"
#import "Sorter/SearchSorter.h"
#import "../Controllers/Cells/VeLogCell.h"
#import "VeDetailListController.h"
#import "../../../Preferences/PreferenceKeys.h"

@interface VeLogsListController ()
@property(nonatomic, strong) dispatch_queue_t logLoadQueue;
@property(nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property(nonatomic, strong) NSArray *loadedSpecifiers;
@property(nonatomic) BOOL loadingLogs;
@property(nonatomic) BOOL reloadPending;
@property(nonatomic) NSUInteger reloadGeneration;
@end

@implementation VeLogsListController
/**
 * Sets up the controller's view.
 */
- (void)viewDidLoad {
    [super viewDidLoad];

    load_preferences();

    [self setSearchController:[[UISearchController alloc] init]];
    [[[self searchController] searchBar] setDelegate:self];
    self.searchController.searchBar.placeholder = @"Search";
    self.searchController.searchBar.accessibilityLabel = @"Search";
    [[self searchController] setObscuresBackgroundDuringPresentation:NO];
    [[self navigationItem] setSearchController:[self searchController]];

    [self setPullToRefreshControl:[[UIRefreshControl alloc] init]];
    [[self pullToRefreshControl] addTarget:self action:@selector(handlePullToRefresh) forControlEvents:UIControlEventValueChanged];
    [[self pullToRefreshControl] setTintColor:[UIColor labelColor]];
    [[self table] setRefreshControl:[self pullToRefreshControl]];

    self.logLoadQueue = dispatch_queue_create("codes.wingchan.ve.logs.load", DISPATCH_QUEUE_SERIAL);
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.table.backgroundView = self.loadingIndicator;
    [self.loadingIndicator startAnimating];
}

/**
 * Sets up the filter button.
 *
 * The filter button needs to be set up after the view has loaded.
 * Otherwise the default "Edit" button will override it.
 *
 * @param animated
 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self setFilterButton:[[UIButton alloc] init]];
    [[self filterButton] setImage:[[UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"] imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:23 weight:UIImageSymbolWeightRegular]] forState:UIControlStateNormal];
    [[self filterButton] setTintColor:[UIColor systemBlueColor]];

    [self createFilterButtonMenu];

    [self setItem:[[UIBarButtonItem alloc] initWithCustomView:[self filterButton]]];
    [[self navigationItem] setRightBarButtonItem:[self item]];
}

/**
 * Creates the remove button's menu.
 */
- (void)createFilterButtonMenu {
    UIAction* applicationSortingAction = [UIAction actionWithTitle:kPreferenceKeySortingApplication image:nil identifier:nil handler:^(__kindof UIAction* _Nonnull action) {
        pfSorting = kPreferenceKeySortingApplication;
        [preferences setObject:pfSorting forKey:kPreferenceKeySorting];
        [self createFilterButtonMenu];
        // Recreate the menu to set the correct state.
        [self reloadSpecifiers];
    }];
    UIAction* dateSortingAction = [UIAction actionWithTitle:kPreferenceKeySortingDate image:nil identifier:nil handler:^(__kindof UIAction* _Nonnull action) {
        pfSorting = kPreferenceKeySortingDate;
        [preferences setObject:pfSorting forKey:kPreferenceKeySorting];
        [self createFilterButtonMenu];
        // Recreate the menu to set the correct state.
        [self reloadSpecifiers];
    }];

    if ([pfSorting isEqualToString:kPreferenceKeySortingApplication]) {
        [applicationSortingAction setState:UIMenuElementStateOn];
    } else if ([pfSorting isEqualToString:kPreferenceKeySortingDate]) {
        [dateSortingAction setState:UIMenuElementStateOn];
    }

    UIMenu* menu = [UIMenu menuWithTitle:@"" children:@[applicationSortingAction, dateSortingAction]];

    [[self filterButton] setMenu:menu];
    [[self filterButton] setShowsMenuAsPrimaryAction:YES];
    self.filterButton.accessibilityLabel = @"Filter";
}

/**
 * Applies the filter button when the app entered the foreground.
 *
 * The filter button is overridden by the default edit button again when the app enters the foreground.
 *
 * @param notification
 */
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [super applicationDidBecomeActive:notification];
    [[self navigationItem] setRightBarButtonItem:[self item]];
}

/**
 * Reloads the specifiers via pull to refresh.
 */
- (void)handlePullToRefresh {
    [self reloadSpecifiers];
}

/**
 * Reloads the specifiers when the search button was tapped.
 *
 * @param searchBar
 */
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self reloadSpecifiers];
}

/**
 * Resets the search bar text when the cancel button was tapped.
 *
 * @param searchBar
 */
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    // The search bar's text is actually cleared by default when the cancel button is clicked.
    // However, it's not cleared before the specifiers are reloaded, so the search results are still shown.
    [[[self searchController] searchBar] setText:@""];
    [self reloadSpecifiers];
}

/**
 * Sets up the specifiers.
 *
 * @return The specifiers.
 */
- (NSArray *)specifiers {
    if (self.loadedSpecifiers) _specifiers = [self.loadedSpecifiers mutableCopy];
    if (!_specifiers) _specifiers = [NSMutableArray arrayWithObject:[PSSpecifier groupSpecifierWithName:@"Loading Notifications..."]];
    return _specifiers;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reloadSpecifiers];
}

- (void)reloadSpecifiers {
    if (!self.logLoadQueue) return;
    self.reloadGeneration++;
    if (self.loadingLogs) {
        self.reloadPending = YES;
        return;
    }
    self.loadingLogs = YES;
    NSUInteger generation = self.reloadGeneration;
    NSString *sorting = [pfSorting copy];
    NSString *search = [self.searchController.searchBar.text copy];
    if (search.length) sorting = kPreferenceKeySortingSearch;
    if (_specifiers.count <= 1) [self.loadingIndicator startAnimating];
    dispatch_async(self.logLoadQueue, ^{
        id sorter = nil;
        if ([sorting isEqualToString:kPreferenceKeySortingApplication]) sorter = [[ApplicationSorter alloc] initWithObject:nil];
        else if ([sorting isEqualToString:kPreferenceKeySortingSearch]) sorter = [[SearchSorter alloc] initWithObject:search];
        else sorter = [[DateSorter alloc] initWithObject:nil];
        NSArray *loaded = [sorter getSpecifiers];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loadingLogs = NO;
            NSString *currentSearch = self.searchController.searchBar.text ?: @"";
            NSString *currentSort = currentSearch.length ? kPreferenceKeySortingSearch : pfSorting;
            BOOL sameQuery = [sorting isEqual:currentSort] && [(search ?: @"") isEqual:currentSearch];
            if (generation == self.reloadGeneration || sameQuery) {
                for (PSSpecifier *specifier in loaded) {
                    [specifier setTarget:self];
                    [specifier setProperty:NSStringFromSelector(@selector(removedSpecifier:)) forKey:PSDeletionActionKey];
                }
                self.loadedSpecifiers = loaded;
                self->_specifiers = [loaded mutableCopy];
                [super reloadSpecifiers];
                [self.loadingIndicator stopAnimating];
                [self.pullToRefreshControl endRefreshing];
            }
            if (self.reloadPending) {
                self.reloadPending = NO;
                [self reloadSpecifiers];
            }
        });
    });
}

/**
 * Removes a log.
 *
 * Called when a specifier was removed.
 *
 * @param specifier The specifier that was removed.
 */
- (void)removedSpecifier:(PSSpecifier *)specifier {
    [[LogManager sharedInstance] removeLog:[specifier propertyForKey:@"log"]];
    [self reloadSpecifiers];
}

/**
 * Prevents the specifiers from reloading on resume.
 *
 * @return Whether to reload the specifiers on resume.
 */
- (BOOL)shouldReloadSpecifiersOnResume {
    return NO;
}

/**
 * Loads the user's preferences.
 */
static void load_preferences() {
    preferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];

    [preferences registerDefaults:@{
        kPreferenceKeySorting: kPreferenceKeySortingDefaultValue
    }];

    pfSorting = [preferences objectForKey:kPreferenceKeySorting];
}
@end
