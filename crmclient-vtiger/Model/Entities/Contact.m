#import "Contact.h"
#import "CRMFieldConstants.h"
#import "CoreData+MagicalRecord.h"
#import "ContactAddress.h"
#import "Service.h"

@interface Contact ()

// Private interface goes here.

@end


@implementation Contact

+ (Contact *)modelObjectWithDictionary:(NSDictionary *)dict customFields:(NSDictionary *)cfields
{
    NSString *record_id = [dict objectForKey:kContactFieldId];
    Contact *instance;
    
    
    //I first try to count the entities (should take less time) and load the entity only if strictly necessary (if count > 0). The Count operation should be less intensive than the Fetch, so I use it for checking the existence
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"crm_id = %@", record_id];
    NSUInteger count = [Contact MR_countOfEntitiesWithPredicate:predicate];
    
    if (count > 0) {
        instance = [Contact MR_findFirstByAttribute:@"crm_id" withValue:record_id];
        NSDateFormatter *dateTimeFormat = [[NSDateFormatter alloc] init];
        [dateTimeFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSDate *time_modified = [dateTimeFormat dateFromString:[dict objectForKey:kFieldModifiedTime]];
        if ([time_modified compare:instance.crm_time_created] == NSOrderedSame) {
#if DEBUG
            NSLog(@"%@ %@ skipping %@ as modified_time is the same", NSStringFromClass([self class]), NSStringFromSelector(_cmd), record_id);
#endif
            //It's the same instance
            return instance;
        }
    }
    else{
        instance = [Contact MR_createEntity];
    }
    
    // This check serves to make sure that a non-NSDictionary object
    // passed into the model class doesn't break the parsing.
    if([dict isKindOfClass:[NSDictionary class]]) {
        
        //Setup the number formatter
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setNumberStyle:NSNumberFormatterNoStyle];
        
        //Setup the date formatters
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"yyyy-MM-dd"];
        NSDateFormatter *timeFormat = [[NSDateFormatter alloc] init];
        [timeFormat setDateFormat:@"HH:mm:ss"];
        
        NSDateFormatter *dateTimeFormat = [[NSDateFormatter alloc] init];
        [dateTimeFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSDate *time_modified = [dateTimeFormat dateFromString:[dict objectForKey:kFieldModifiedTime]];
        NSDate *time_created = [dateTimeFormat dateFromString:[dict objectForKey:kFieldCreatedTime]];
        instance.crm_time_modified = time_modified;
        instance.crm_time_created = time_created;
        
        instance.crm_id = [dict objectForKey:kContactFieldId];
        instance.crm_account_id = [[dict objectForKey:kContactFieldAccount] objectForKey:@"value"];
        instance.crm_account_name = [[dict objectForKey:kContactFieldAccount] objectForKey:@"label"];
        instance.crm_assigned_user_id = [[dict objectForKey:kContactFieldAssignedTo] objectForKey:@"value"];
        instance.crm_assigned_user_name = [[dict objectForKey:kContactFieldAssignedTo] objectForKey:@"label"];
        instance.crm_assistant = [dict objectForKey:kContactFieldAssistant];
        instance.crm_assistantphone = [dict objectForKey:kContactFieldAssistantPhone];
        instance.crm_birthday = [dict objectForKey:kContactFieldBirthday];
        //        instance.crm_contact_image =
        instance.crm_contact_no = [dict objectForKey:kContactFieldContactNo];
        instance.crm_department = [dict objectForKey:kContactFieldDepartment];
        instance.crm_description = [dict objectForKey:kContactFieldDescription];
        instance.crm_email = [dict objectForKey:kContactFieldEmail];
        instance.crm_fax = [dict objectForKey:kContactFieldFax];
        instance.crm_firstname = [dict objectForKey:kContactFieldFirstName];
        instance.crm_homephone = [dict objectForKey:kContactFieldHomePhone];
        instance.crm_lastname = [dict objectForKey:kContactFieldLastName];
        instance.crm_leadsource = [dict objectForKey:kContactFieldLeadSource];
        instance.crm_mobile = [dict objectForKey:kContactFieldMobile];
        instance.crm_otherphone = [dict objectForKey:kContactFieldOtherPhone];
        instance.crm_phone = [dict objectForKey:kContactFieldPhone];
        instance.crm_reports_to_id = [[dict objectForKey:kContactFieldReportsTo] objectForKey:@"value"];
        instance.crm_reports_to_name = [[dict objectForKey:kContactFieldReportsTo] objectForKey:@"label"];
        instance.crm_salutationtype = [dict objectForKey:kContactFieldSalutation];
        instance.crm_title = [dict objectForKey:kContactFieldTitle];
        instance.crm_yahooid = [dict objectForKey:kContactFieldYahooId];
        
        if (instance.address == nil) {
            instance.address = [ContactAddress MR_createEntity];
        }
        [instance.address assignFieldsFromDictionary:dict];
        
        //Custom fields
        NSError *cfieldsError;
        if(cfields != nil) {
            instance.my_custom_fields = [NSJSONSerialization dataWithJSONObject:cfields options:NSJSONWritingPrettyPrinted error:&cfieldsError];
            if (cfieldsError != nil) {
                NSLog(@"Entity: %@ Error in custom fields: %@", instance.crm_id, [cfieldsError description]);
            }
        }
        
        //Add the relationship with the current service
        instance.service = [Service getActive];
        
        
    }
    
    return instance;
}

@end
