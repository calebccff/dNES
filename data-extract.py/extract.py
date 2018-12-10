
import pandas as pd

df_list = pd.read_html('data.html')

for i, df in enumerate(df_list):
    print(df)
    df.to_csv('table {}.csv'.format(i), sep='#')
