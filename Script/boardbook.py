from selenium import webdriver
import time
import getpass
from selenium.webdriver.support.select import Select

username = input("usrname:")
password = getpass.getpass("password:")

# 打卡网页,输入账号密码
driver = webdriver.Ie()
driver.get("http://cadp.changan.com/web/QyyEnter.aspx?ReturnUrl=http://cadp.changan.com/web/login.aspx?URL=http://10.30.200.15:9090/")
driver.find_element_by_id('TextBox_UserName').send_keys(username)
driver.find_element_by_id('TextBox_PassWord').send_keys(password)
driver.find_element_by_id('Button_Enter').click()
driver.switch_to.alert.accept()
time.sleep(2)
driver.find_element_by_id('ctl00_TreeView1t2').click()

# 打开iframe页,输入信息
driver.get('http://10.30.200.15:9090/approva/MaterialRequest.aspx')
driver.find_element_by_id('GridView1_ctl02_TextBox_MaterialName').send_keys('域控板子')
driver.find_element_by_id('GridView1_ctl02_TextBox_MaterialStandard').send_keys('1')
driver.find_element_by_id('GridView1_ctl02_TextBox_MaterialCode').send_keys('S19416')
driver.find_element_by_id('GridView1_ctl02_TextBox_Units').send_keys('个')
driver.find_element_by_id('GridView1_ctl02_TextBox_Quantity').send_keys('1')
driver.find_element_by_id('GridView1_ctl02_FileUpload1').send_keys(r'D:\a.jpg')
driver.find_element_by_id('GridView1_ctl02_TextBox_Notes').send_keys('LS6A2E160NA500135 ')
Select(driver.find_element_by_id('DropDownList_flowType')).select_by_index('1')
Select(driver.find_element_by_id('DropDownList_Type')).select_by_index('1')
Select(driver.find_element_by_id('DropDownList_area')).select_by_index('33')
Select(driver.find_element_by_id('DropDownList_gate')).select_by_index('1')
driver.find_element_by_id('TextBox_des').send_keys('地下车库')
driver.find_element_by_id('TextBox_reason').send_keys('集成调试')
driver.find_element_by_id('TextBox_sh1').click()

# 切换到网页对话框
all_handles = driver.window_handles
driver.switch_to.window(all_handles[-1])
time.sleep(1)
# 获取网页源码,定位元素
page = driver.page_source
driver.find_element_by_xpath('//*[@id="Text_Search"]').send_keys('王宽')
driver.find_element_by_xpath('//*[@id="content1"]/div/img').click()
page = driver.page_source
driver.find_element_by_xpath('//*[@id="P_63118"]').click()
# 切换到上一个句柄
driver.switch_to.window(all_handles[0])
driver.find_element_by_id('Button1').click()
print("任务书提交完毕")