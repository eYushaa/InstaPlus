#import "GalleryListViewController.h"
#import "UserGalleryViewController.h"
#import "LocalPhotoManager.h"
#import "InstaLocalization.h"

@interface GalleryListViewController () <UISearchResultsUpdating>
@property (nonatomic, strong) NSMutableArray<NSString *> *usernames;
@property (nonatomic, strong) NSMutableArray<NSString *> *filteredUsernames;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation GalleryListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"saved_users");
    
    // Tümü Butonu (Sağ Üst)
    UIBarButtonItem *allItem = [[UIBarButtonItem alloc] initWithTitle:L(@"all") style:UIBarButtonItemStylePlain target:self action:@selector(openAllMedia)];
    self.navigationItem.rightBarButtonItem = allItem;
    
    // Arama Çubuğu
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = L(@"search_username");
    self.searchController.searchBar.barStyle = UIBarStyleBlack;
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    self.tableView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:0.4];
    
    [self loadUsernames];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadUsernames];
}

- (void)openAllMedia {
    UserGalleryViewController *vc = [[UserGalleryViewController alloc] initWithUsername:L(@"all")];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)loadUsernames {
    self.usernames = [[[LocalPhotoManager sharedManager] getSavedUsernames] mutableCopy];
    if (self.searchController.isActive && self.searchController.searchBar.text.length > 0) {
        [self updateSearchResultsForSearchController:self.searchController];
    } else {
        self.filteredUsernames = [self.usernames mutableCopy];
        [self.tableView reloadData];
    }
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text.lowercaseString;
    if (searchText.length == 0) {
        self.filteredUsernames = [self.usernames mutableCopy];
    } else {
        self.filteredUsernames = [NSMutableArray array];
        for (NSString *un in self.usernames) {
            if ([un.lowercaseString containsString:searchText]) {
                [self.filteredUsernames addObject:un];
            }
        }
    }
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.filteredUsernames.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
        emptyLabel.text = self.searchController.isActive ? L(@"no_results") : L(@"no_users_saved");
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.textColor = [UIColor grayColor];
        self.tableView.backgroundView = emptyLabel;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
    return self.filteredUsernames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.textLabel.text = [NSString stringWithFormat:@"👤  @%@", self.filteredUsernames[indexPath.row]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *username = self.filteredUsernames[indexPath.row];
    UserGalleryViewController *vc = [[UserGalleryViewController alloc] initWithUsername:username];
    [self.navigationController pushViewController:vc animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *usernameToDelete = self.filteredUsernames[indexPath.row];
        
        UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:L(@"delete_user")
                                                                               message:[NSString stringWithFormat:L(@"delete_user_confirm_format"), usernameToDelete]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
        
        [confirmAlert addAction:[UIAlertAction actionWithTitle:L(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
        [confirmAlert addAction:[UIAlertAction actionWithTitle:L(@"yes_delete_all") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            NSError *error = nil;
            BOOL success = [[LocalPhotoManager sharedManager] deleteGalleryForUsername:usernameToDelete error:&error];
            if (success) {
                [self.usernames removeObject:usernameToDelete];
                [self.filteredUsernames removeObjectAtIndex:indexPath.row];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            } else {
                UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:L(@"error") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [errAlert addAction:[UIAlertAction actionWithTitle:L(@"ok") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errAlert animated:YES completion:nil];
            }
        }]];
        
        [self presentViewController:confirmAlert animated:YES completion:nil];
    }
}

@end
